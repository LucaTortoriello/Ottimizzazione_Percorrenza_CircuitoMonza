%% ============================================================
%%  MONZA - PUNTO 2 - MENU INTERATTIVO
%  Legge il dataset dal file Excel e permette di:
%    Modalità 1 → cerca per tempo noto da statistiche F1
%    Modalità 2 → inserisci un tempo personalizzato
%% ============================================================

clear all; close all; clc;

fprintf('==========================================================\n');
fprintf('       OTTIMIZZAZIONE MONZA GARA - DATI STORICI \n');
fprintf('==========================================================\n');

%% ── 1) LETTURA DATASET EXCEL ──────────────────────────────────
dataset_file = 'monza_dataset.xlsx';

if ~isfile(dataset_file)
    error(['File "%s" non trovato.\n' ...
           'Esegui prima: python genera_dataset.py'], dataset_file);
end

fprintf('Caricamento dataset da "%s" ...\n', dataset_file);
T_data = readtable(dataset_file, 'Sheet', 'Dataset');
T_data.Properties.VariableNames = {'mu', 'W', 'Tempo_s', 'Tempo_min'};
fprintf('Dataset caricato: %d combinazioni  (mu × W)\n\n', height(T_data));

%% ── 2) TEMPI F1 STORICI MONZA ────────────────────────────────
% Format: {Anno, Pilota, Tempo [s]}
f1_times = {
    2025, 'L. Norris',      80.901;
    2024, 'L. Norris',      81.432;
    2023, 'O. Piastri',     85.072;
    2022, 'S. Perez',       84.030;
    2021, 'D. Ricciardo',   84.812;
    2020, 'L. Hamilton',    82.746;
    2019, 'L. Hamilton',    81.779;
    2018, 'L. Hamilton',    82.497;
    2017, 'D. Ricciardo',   83.361;
    2016, 'F. Alonso',      85.340;
    2015, 'L. Hamilton',    86.672;
    2014, 'L. Hamilton',    88.004;
    2013, 'L. Hamilton',    85.849;
    2012, 'N. Rosberg',     87.239;
    2011, 'L. Hamilton',    86.187;
    2010, 'F. Alonso',      84.139;
    2009, 'A. Sutil',       84.739;
    2008, 'K. Raikkonen',   88.047;
    2007, 'F. Alonso',      82.871;
    2006, 'K. Raikkonen',   82.559;
    2005, 'K. Raikkonen',   81.504;
    2004, 'R. Barrichello', 81.046;
    2003, 'M. Schumacher',  81.832;
    2002, 'R. Barrichello', 83.657;
    2001, 'R. Schumacher',  85.073;
    2000, 'M. Hakkinen',    85.595;
    1999, 'R. Schumacher',  85.579;
    1998, 'M. Hakkinen',    85.139;
    1997, 'M. Hakkinen',    84.808;
    1996, 'M. Schumacher',  86.110;
    1995, 'G. Berger',      86.419;
    1994, 'D. Hill',        85.930;
    1993, 'D. Hill',        83.575;
    1992, 'N. Mansell',     86.119;
    1991, 'A. Senna',       86.061;
    1990, 'A. Senna',       86.254;
    1989, 'A. Prost',       88.107;
    1988, 'M. Alboreto',    89.070;
    1987, 'A. Senna',       86.796;
    1986, 'T. Fabi',        88.099;
    1985, 'N. Mansell',     88.283;
    1984, 'N. Lauda',       91.912;
    1983, 'N. Piquet',      94.431;
    1982, 'R. Arnoux',      93.619;
    1981, 'C. Reutemann',   97.528;
    1979, 'C. Regazzoni',   95.600;
    1978, 'M. Andretti',    98.230;
    1977, 'M. Andretti',    99.100;
    1976, 'R. Peterson',    101.300;
    1975, 'C. Regazzoni',   93.100;
    1974, 'C. Pace',        94.200;
    1973, 'J. Stewart',     95.300;
    1972, 'J. Ickx',        96.300;
    1971, 'H. Pescarolo',   83.800;
    1970, 'C. Regazzoni',   85.200;
    1969, 'J. Beltoise',    85.200;
    1968, 'J. Oliver',      86.500;
    1967, 'J. Clark',       88.500;
    1966, 'L. Scarfiotti',  92.400;
    1965, 'J. Clark',       96.400;
    1964, 'J. Surtees',     98.800;
    1963, 'J. Clark',       98.900;
    1962, 'G. Hill',        102.300;
    1961, 'G. Baghetti',    168.400; 
    1960, 'P. Hill',        163.600; 
    1959, 'P. Hill',        100.400;
    1958, 'P. Hill',        102.900;
    1957, 'T. Brooks',      103.700;
};

%% ── 3) MENU PRINCIPALE ───────────────────────────────────────
while true
    fprintf('\n---------------------------------------------------------\n');
    fprintf('  MENU PRINCIPALE\n');
    fprintf('    [1]  Cerca da statistiche F1 (giri veloci in gara: Monza)\n');
    fprintf('    [2]  Inserisci un tempo personalizzato\n');
    fprintf('    [0]  Esci\n');
    fprintf('---------------------------------------------------------\n');
    scelta = input('Scelta: ', 's');
    scelta = strtrim(scelta);

    if strcmp(scelta, '0')
        fprintf('Arrivederci!\n');
        break;

    elseif strcmp(scelta, '1')
        %% ─── MODALITÀ 1: tempi F1 ────────────────────────────
        fprintf('\n  TEMPI F1 STORICI - MONZA (Giro veloce in gara)\n');
        fprintf('  %-4s  %-22s  %-12s  %-10s\n', 'ID', 'Pilota', 'Tempo [s]', 'Tempo [m]');
        fprintf('  %s\n', repmat('-',1,52));
        for k = 1:size(f1_times,1)
            ts = f1_times{k,3};
            fprintf('  [%2d]  %-22s  %9.3f s   %s\n', ...
                k, ...
                sprintf('%d - %s', f1_times{k,1}, f1_times{k,2}), ...
                ts, ...
                sec2mmss(ts));
        end
        fprintf('\n');
        idx_str = input('Seleziona ID del tempo o pilota F1 (es: 1): ', 's');
        idx = str2double(strtrim(idx_str));
        if isnan(idx) || idx<1 || idx>size(f1_times,1)
            fprintf('[ERRORE] ID non valido.\n'); continue;
        end
        T_target = f1_times{idx,3};
        fprintf('\n  Tempo selezionato: %s → %.3f s (%s)\n', ...
            sprintf('%d %s', f1_times{idx,1}, f1_times{idx,2}), ...
            T_target, sec2mmss(T_target));
        cerca_nel_dataset(T_data, T_target);

    elseif strcmp(scelta, '2')
        %% ─── MODALITÀ 2: tempo personalizzato ────────────────
        fprintf('\n  Inserimento tempo personalizzato\n');
        fprintf('  Formato accettato: secondi (es: 82.5)  oppure  mm:ss.mmm (es: 1:22.500)\n');
        t_str = input('  Inserisci il tempo: ', 's');
        T_target = parse_time_input(strtrim(t_str));
        if isnan(T_target)
            fprintf('[ERRORE] Formato non riconosciuto. Usa secondi (82.5) o mm:ss (1:22.500)\n');
            continue;
        end
        fprintf('\n  Tempo inserito: %.3f s  (%s)\n', T_target, sec2mmss(T_target));
        cerca_nel_dataset(T_data, T_target);

    else
        fprintf('[ERRORE] Scelta non valida. Inserisci 0, 1 o 2.\n');
    end
end


%% ══════════════════════════════════════════════════════════════
%  FUNZIONI LOCALI
%  ══════════════════════════════════════════════════════════════

function cerca_nel_dataset(T_data, T_target)
% Trova le coppie (mu,W) nel dataset entro lo 0.1% dal target.

    tol = 0.001;  % tolleranza
    err_pct = abs(T_data.Tempo_s - T_target) ./ T_target;
    mask    = err_pct <= tol;
    idx     = find(mask);

    if isempty(idx)
        fprintf('\n  [NESSUN RISULTATO] Nessuna configurazione entro lo 0.1%%.\n');
        % Mostra il più vicino
        [min_err, imin] = min(err_pct);
        fprintf('  Configurazione più vicina:\n');
        stampa_riga(T_data(imin,:), min_err*100);
        return;
    end

    % Ordina per errore crescente
    [~, sort_idx] = sort(err_pct(idx));
    idx_sorted    = idx(sort_idx);

    fprintf('\n  Trovate %d configurazione/i entro lo 0.1%% dal tempo target (%.3f s)\n', ...
        numel(idx_sorted), T_target);
    fprintf('  %-10s  %-12s  %-12s  %-10s  %-8s  %s\n', ...
        'mu [-]', 'W [s/L]', 'Tempo [s]', 'Tempo', 'Err %', 'Descrizione');
    fprintf('  %s\n', repmat('-',1,82));

    for k = 1:numel(idx_sorted)
        row = T_data(idx_sorted(k), :);
        stampa_riga(row, err_pct(idx_sorted(k))*100);
    end
    fprintf('\n');
end

function stampa_riga(row, err_pct)
%STAMPA_RIGA  Stampa una riga del dataset con interpretazione mu e W.

    mu_val = row.mu;
    W_val  = row.W;
    Ts     = row.Tempo_s;

    % Interpretazione mu
    if mu_val >= 1.0 && mu_val <= 1.5
        cond_str = 'Gomma Dura';
    elseif mu_val >= 1.6 && mu_val <= 2.5
        cond_str = 'Gomma Media';
    elseif mu_val >= 2.6 && mu_val <= 3.5
        cond_str = 'Gomma soft';
    else
        cond_str = 'Fuori range';
    end

    fprintf('  mu=%-6.2f  W=%-8.2f  %9.3f s  %s  Err=%5.3f%%\n', ...
        mu_val, W_val, Ts, sec2mmss(Ts), err_pct);
    fprintf('         → Condizione pista : %s\n', cond_str);
    fprintf('         → Peso consumo     : stai "pagando" %.2f s per ogni litro di benzina\n', W_val);
end

function str = sec2mmss(s)
%SEC2MMSS  Converte secondi in stringa mm:ss.mmm
    m   = floor(s / 60);
    rem = s - m*60;
    str = sprintf('%d:%06.3f', m, rem);
end

function T = parse_time_input(s)
%PARSE_TIME_INPUT  Accetta "82.5" (secondi) oppure "1:22.500" (mm:ss).
    T = NaN;
    if contains(s, ':')
        % formato mm:ss[.mmm]
        parts = strsplit(s, ':');
        if numel(parts) ~= 2; return; end
        mm = str2double(parts{1});
        ss = str2double(parts{2});
        if isnan(mm) || isnan(ss); return; end
        T = mm*60 + ss;
    else
        T = str2double(s);
    end
end