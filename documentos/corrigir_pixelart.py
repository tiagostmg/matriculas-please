#!/usr/bin/env python3
"""
Corrige pixel art borrada (v2).
- Paleta aprendida só das áreas chapadas -> as cores "misturadas" das bordas não entram
- Cada célula recebe a cor MAIS FREQUENTE (moda) -> nunca cria cor intermediária
- Suporta pastas com subpastas de personagens (01..48) ou arquivos soltos.

Uso:
    python3 corrigir_pixelart.py ../sprites/personagens ../sprites/personagens-64 --grade 64
    python3 corrigir_pixelart.py ../sprites/personagens ../sprites/personagens-85 --grade 85
"""
import argparse
import os
from concurrent.futures import ProcessPoolExecutor
import numpy as np
from PIL import Image
from scipy import ndimage
from scipy.cluster.vq import kmeans2


def kmeans_centers(px, colors, n_init=4, seed=0):
    rng = np.random.default_rng(seed)
    px_f = px.astype(np.float64)
    best_centers = None
    best_inertia = np.inf
    for _ in range(n_init):
        centers, labels = kmeans2(px_f, colors, iter=25, minit="++", seed=rng)
        diff = px_f - centers[labels]
        inertia = np.einsum("ij,ij->", diff, diff)
        if inertia < best_inertia:
            best_inertia = inertia
            best_centers = centers
    return best_centers


def flat_mask(rgb, pct=55):
    g = sum(np.abs(ndimage.sobel(rgb[..., c], axis=ax)) for c in range(3) for ax in (0, 1))
    return g < np.percentile(g, pct)


def build_palette(rgb, alpha, colors):
    px = rgb[flat_mask(rgb) & (alpha > 128)]
    pal = list(kmeans_centers(px, colors, n_init=4, seed=0))
    lum = rgb @ np.array([0.3, 0.59, 0.11])
    vis = alpha > 128
    bright = rgb[(lum > np.percentile(lum[vis], 99.3)) & vis]  # dentes, brilho dos olhos
    if len(bright):
        pal.append(np.median(bright, 0))
    return np.array(pal)


def purity(idx, N, off, cs):
    H, W = idx.shape
    tot = n = 0
    for y in range(N):
        y0, y1 = int(off + y * cs), int(off + (y + 1) * cs)
        if y1 > H:
            break
        for x in range(N):
            x0, x1 = int(off + x * cs), int(off + (x + 1) * cs)
            if x1 > W:
                break
            c = np.bincount(idx[y0:y1, x0:x1].ravel())
            tot += c.max() / c.sum()
            n += 1
    return tot / max(n, 1)


def depixel(img, colors=28, grade=None, out=256):
    a = np.asarray(img.convert("RGBA")).astype(float)
    rgb, alpha = a[..., :3], a[..., 3]
    W = alpha.shape[1]
    pal = build_palette(rgb, alpha, colors)
    idx = ((rgb[..., None, :] - pal[None, None]) ** 2).sum(-1).argmin(-1)
    grids = [grade] if grade else range(60, 100)
    best = None
    for N in grids:
        cs = W / N
        for off in np.linspace(0, cs, 4, endpoint=False):
            s = purity(idx, N - 1, off, cs) - 0.0008 * N
            if best is None or s > best[0]:
                best = (s, N, off)
    _, N, off = best
    cs = W / N
    M = int((W - off) // cs)
    res = np.zeros((M, M, 4), np.uint8)
    for y in range(M):
        for x in range(M):
            y0, x0 = int(off + y * cs + cs * 0.2), int(off + x * cs + cs * 0.2)
            y1 = max(int(off + (y + 1) * cs - cs * 0.2), y0 + 1)
            x1 = max(int(off + (x + 1) * cs - cs * 0.2), x0 + 1)
            if np.median(alpha[y0:y1, x0:x1]) > 128:
                res[y, x, :3] = pal[np.bincount(idx[y0:y1, x0:x1].ravel()).argmax()].round()
                res[y, x, 3] = 255
    small = Image.fromarray(res)
    return small, small.resize((out, out), Image.NEAREST), N


def _process_one(task):
    in_path, out_big_path, out_small_path, colors, grade, tamanho = task
    os.makedirs(os.path.dirname(out_big_path), exist_ok=True)
    os.makedirs(os.path.dirname(out_small_path), exist_ok=True)
    small, big, N = depixel(Image.open(in_path), colors, grade, tamanho)
    big.save(out_big_path, optimize=True)
    small.save(out_small_path, optimize=True)
    return in_path, N


def process_directory(entrada, saida, cores=28, grade=None, tamanho=256):
    tasks = []
    for root, _, files in os.walk(entrada):
        rel_dir = os.path.relpath(root, entrada)
        if rel_dir.startswith("nativo"):
            continue
        for f in sorted(files):
            if f.lower().endswith((".png", ".jpg", ".jpeg", ".webp")):
                in_path = os.path.join(root, f)
                nome = os.path.splitext(f)[0] + ".png"
                if rel_dir == ".":
                    out_big = os.path.join(saida, nome)
                    out_small = os.path.join(saida, "nativo", nome)
                else:
                    out_big = os.path.join(saida, rel_dir, nome)
                    out_small = os.path.join(saida, "nativo", rel_dir, nome)
                tasks.append((in_path, out_big, out_small, cores, grade, tamanho))

    tasks.sort(key=lambda t: t[0])
    print(f"Processando {len(tasks)} imagens -> {saida} (grade={grade or 'auto'}, tamanho={tamanho}x{tamanho})...")
    with ProcessPoolExecutor() as ex:
        for idx, (in_path, N) in enumerate(ex.map(_process_one, tasks), 1):
            if idx % 24 == 0 or idx == len(tasks):
                rel = os.path.relpath(in_path, entrada)
                print(f"  [{idx}/{len(tasks)}] ok {rel} (grade {N})")


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("entrada")
    p.add_argument("saida")
    p.add_argument("--cores", type=int, default=28)
    p.add_argument("--grade", type=int, default=None, help="força o tamanho da grade (senão detecta)")
    p.add_argument("--tamanho", type=int, default=256)
    a = p.parse_args()
    process_directory(a.entrada, a.saida, a.cores, a.grade, a.tamanho)
