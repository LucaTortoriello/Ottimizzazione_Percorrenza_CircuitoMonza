"""
Genera il dataset Monza sweepando mu (1:0.2:3.5) e W (0.4:0.2:20).
Per ogni coppia (mu, W) risolve il problema di ottimizzazione tempo+consumo
e salva il tempo in secondi e minuti nel file monza_dataset.xlsx
"""

import numpy as np
from scipy.optimize import minimize
import openpyxl
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.utils import get_column_letter
import warnings
warnings.filterwarnings('ignore')

# ── DATI CIRCUITO ──────────────────────────────────────────────────────────────
L = np.array([324.33, 458.00, 687.00, 412.00, 229.00,
              229.00, 916.00, 916.00, 705.67, 916.00])

x_brake = np.array([122.0, 0.0, 0.0, 107.0, 0.0, 35.0, 50.0, 104.0, 76.0, 0.0])
dist_frenata = 380.0
x_acc   = np.array([202.33, dist_frenata, dist_frenata, 305.0, 229.0,
                    194.0, dist_frenata, dist_frenata, dist_frenata, dist_frenata])
x_const = L - x_acc - x_brake

m        = 730.0
g        = 9.81
k_aero   = 0.387
epsilon  = 6e-6

def build_vlim(mu):
    rho    = 224.62
    beta   = np.sqrt(mu * rho * g) * 3.6  # km/h
    return np.array([90, 315, 135, 195, 170, 325, 185, beta, beta, 360.0]) / 3.6  # m/s

def obj(v_peak, xa, xc, xb, v_lim, W):
    T = 0.0; C = 0.0; v_in = 0.1
    for i in range(len(v_peak)):
        vp = v_peak[i]; vt = v_lim[i]
        T += xa[i]/((v_in+vp)/2) + xc[i]/vp + xb[i]/((vp+vt)/2)
        v_a = ((v_in+vp)/2)*3.6;  v_c = vp*3.6;  v_b = ((vp+vt)/2)*3.6
        C += epsilon*(v_a**2)*(xa[i]/1000) + epsilon*(v_c**2)*(xc[i]/1000) + epsilon*(v_b**2)*(xb[i]/1000)
        v_in = vt
    return T + W * C

def build_constraints(xa, xb, v_lim, mu):
    F_grip = mu * m * g
    cons = []
    def make_con(i):
        def c(v):
            v_in = 0.1 if i == 0 else v_lim[i-1]
            vp = v[i]; vt = v_lim[i]
            F_acc = F_grip - k_aero*((v_in+vp)/2)**2
            F_brk = F_grip + k_aero*((vp+vt)/2)**2
            c1 = F_acc*xa[i] - 0.5*m*(vp**2 - v_in**2)
            c2 = F_brk*xb[i] - 0.5*m*(vp**2 - vt**2)
            return np.array([c1, c2])
        return c
    for i in range(len(xa)):
        cons.append({'type': 'ineq', 'fun': make_con(i)})
    return cons

def solve(mu, W):
    v_lim   = build_vlim(mu)
    lb      = v_lim.copy()
    ub      = np.full(len(lb), 360/3.6)
    v0      = np.clip(v_lim + 10, lb, ub)
    bounds  = list(zip(lb, ub))
    cons    = build_constraints(x_acc, x_brake, v_lim, mu)
    res = minimize(obj, v0, args=(x_acc, x_const, x_brake, v_lim, W),
                   method='SLSQP', bounds=bounds, constraints=cons,
                   options={'ftol':1e-9, 'maxiter':2000, 'disp':False})
    # Calcola tempo puro
    vp = res.x; v_in = 0.1; T = 0.0
    for i in range(len(vp)):
        vt = v_lim[i]
        T += x_acc[i]/((v_in+vp[i])/2) + x_const[i]/vp[i] + x_brake[i]/((vp[i]+vt)/2)
        v_in = vt
    return T  # secondi

# ── SWEEP ──────────────────────────────────────────────────────────────────────
mu_vals = np.round(np.arange(1.0, 3.6, 0.2), 2)
W_vals  = np.round(np.arange(0.4, 20.2, 0.2), 2)

total = len(mu_vals) * len(W_vals)
print(f"Calcolo {total} combinazioni (mu x W) ...")

results = []
for idx_mu, mu in enumerate(mu_vals):
    for idx_W, W in enumerate(W_vals):
        T_s = solve(mu, W)
        T_m = T_s / 60.0
        results.append((mu, W, T_s, T_m))
        done = idx_mu*len(W_vals) + idx_W + 1
        if done % 50 == 0 or done == total:
            print(f"  {done}/{total}  mu={mu:.1f}  W={W:.1f}  T={T_s:.3f}s")

# ── EXCEL ──────────────────────────────────────────────────────────────────────
wb = openpyxl.Workbook()
ws = wb.active
ws.title = "Dataset"

# Stili
hdr_font   = Font(name='Arial', bold=True, color='FFFFFF', size=11)
hdr_fill   = PatternFill('solid', start_color='1F4E79')
alt_fill   = PatternFill('solid', start_color='D6E4F0')
num_fmt_s  = '0.000'
num_fmt_m  = '0.00000'
center     = Alignment(horizontal='center', vertical='center')
thin       = Side(style='thin', color='AAAAAA')
border     = Border(left=thin, right=thin, top=thin, bottom=thin)

headers = ['mu [-]', 'W [s/L]', 'Tempo [s]', 'Tempo [min]']
col_widths = [12, 12, 14, 14]

for col, (h, w) in enumerate(zip(headers, col_widths), start=1):
    cell = ws.cell(row=1, column=col, value=h)
    cell.font = hdr_font; cell.fill = hdr_fill
    cell.alignment = center; cell.border = border
    ws.column_dimensions[get_column_letter(col)].width = w

for row_idx, (mu, W, Ts, Tm) in enumerate(results, start=2):
    fill = alt_fill if row_idx % 2 == 0 else None
    vals = [mu, W, round(Ts, 6), round(Tm, 8)]
    fmts = [None, None, num_fmt_s, num_fmt_m]
    for col, (v, f) in enumerate(zip(vals, fmts), start=1):
        cell = ws.cell(row=row_idx, column=col, value=v)
        cell.alignment = center; cell.border = border
        if f: cell.number_format = f
        if fill: cell.fill = fill

# Freeze header
ws.freeze_panes = 'A2'

# Foglio README
ws2 = wb.create_sheet("README")
ws2['A1'] = 'DATASET MONZA - Sweep mu e W'
ws2['A1'].font = Font(bold=True, size=14)
ws2['A2'] = f'mu range: {mu_vals[0]} ÷ {mu_vals[-1]} (step 0.2)  —  {len(mu_vals)} valori'
ws2['A3'] = f'W  range: {W_vals[0]} ÷ {W_vals[-1]} (step 0.2)  —  {len(W_vals)} valori'
ws2['A4'] = f'Totale combinazioni: {len(results)}'
ws2['A5'] = ''
ws2['A6'] = 'Colonne:'
ws2['A7'] = '  mu [-]      → coefficiente di aderenza pneumatico'
ws2['A8'] = '  W [s/L]     → peso del consumo nella funzione obiettivo'
ws2['A9'] = '  Tempo [s]   → tempo giro ottimizzato (secondi)'
ws2['A10']= '  Tempo [min] → tempo giro ottimizzato (minuti)'
ws2['A11']= ''
ws2['A12']= 'Lettura MATLAB: readtable("monza_dataset.xlsx")'
ws2.column_dimensions['A'].width = 55

out_path = "monza_dataset.xlsx"
wb.save(out_path)
print(f"\nDataset salvato in: {out_path}")
print(f"Righe dati: {len(results)}  (+ 1 header)")