%% REVERSE ENGINEERING F1 MONZA - STIMA V_LIMITS AI NODI
clear all; close all; clc;

warning('off', 'optimlib:commonMsgs:reducedStepFwdDiff');
warning('off', 'optimlib:fmincon:WillRunDiffEvol');
warning('off', 'MATLAB:fmincon:WillRunDiffEvol');
% Sopprimi tutti i warning
warning('off','all');


%% ============================================================
% 1. LAYOUT MONZA - DATI BASE E SETUP COMUNE
% ============================================================
L = [324.33, 458.00, 687.00, 412.00, 229.00, 229.00, 916.00, 916.00, 705.67, 916.00]';
x_brake = [122.0, 0.0, 0.0, 107.0, 0.0, 35.0, 50.0, 104.0, 76.0, 0.0]';
distanza_frenata = 380;
x_acc   = [202.33, distanza_frenata, distanza_frenata, 305.0, 229.0, 194.0, distanza_frenata, distanza_frenata, distanza_frenata, distanza_frenata]';
x_const = L - x_acc - x_brake;

% Parametri Fisici FISSI
m      = 620;
k_aero = 0.387;
mu     = 3; 
g      = 9.81;
F_grip = mu * m * g;
n_tratti = length(L);
nomi_curva = {'Variante1','CrvGrande','Roggia','Lesmo1','Lesmo2','Serraglio','Ascari','RettOpp','Parabolica','Traguardo'};
rho = 224.62;

% Velocità ai nodi di RIFERIMENTO moderno [km/h → m/s]
beta = sqrt(mu*rho*g)*3.6; % in km/h
v_limits_ref_kmh = [90; 315; 135; 195; 170; 325; 185; beta; beta; 360.0];
v_limits_ref = v_limits_ref_kmh / 3.6;

% Upper bound per le V_peak interne: 360 km/h globale, 106.88 per Parabolica
% Costruito una volta sola e riusato in tutte le chiamate alle funzioni simulate_*
ub_peak_ms = ones(n_tratti, 1) * (360 / 3.6);

ub_peak_ms(8) = beta / 3.6;  
ub_peak_ms(9) = beta / 3.6; % Parabolica: V_peak non può superare V_nodo

% Calcolo dei "pesi" percentuali dei settori basati sulle dinamiche moderne
[t_settori_mod, ~] = simulate_sector_times(v_limits_ref, x_acc, x_const, x_brake, m, k_aero, F_grip, ub_peak_ms);
pesi_settori = t_settori_mod / sum(t_settori_mod);

% Setup Opzioni Ottimizzatore (comune a entrambe le scelte)
lb_out = ones(n_tratti, 1) * (60 / 3.6);  % Lower bound
ub_out = ones(n_tratti, 1) * (360 / 3.6); % Upper bound
ub_out(8) = beta / 3.6;                   % VINCOLO PARABOLICA
ub_out(9) = beta / 3.6;  
options_out = optimoptions('lsqnonlin', 'Display', 'off', 'FunctionTolerance', 1e-4, 'StepTolerance', 1e-4);

%% ============================================================
% 2. MENU INTERATTIVO
% ============================================================
fprintf('=====================================================================\n');
fprintf(' REVERSE ENGINEERING MONZA - MENU PRINCIPALE                         \n');
fprintf('=====================================================================\n');
fprintf(' 1) Analisi Storica F1 (Tempi 1957-1971)\n');
fprintf(' 2) Inserisci un tempo sul giro personalizzato\n');
fprintf('=====================================================================\n');

scelta = input('Scegli un''opzione (1 o 2): ');

switch scelta
    case 1
        %% CASO 1: DATI STORICI POLE POSITION
        anni   = [1957, 1958, 1959, 1962, 1963, 1964, 1965, 1966, 1967, 1968, 1969, 1970, 1971];
        driver = {'LEWIS-EVANS','MOSS','MOSS','CLARK','SURTEES','SURTEES','CLARK','PARKES','CLARK','SURTEES','RINDT','ICKX','AMON'};
        tempi_str = {'1:42.400','1:40.500','1:39.700','1:40.350','1:37.300','1:37.400',...
                     '1:35.900','1:31.300','1:28.500','1:26.070','1:25.480','1:24.140','1:22.400'};
        
        % CONVERTO IN SECONDI
        T_target_tot = zeros(length(tempi_str),1);
        for i = 1:length(tempi_str)
            parts = strsplit(tempi_str{i}, ':');
            T_target_tot(i) = str2double(parts{1})*60 + str2double(parts{2});
        end
        
        fprintf('\nEsecuzione ottimizzazione sui dati storici...\n');
        v_limits_history = zeros(length(anni), n_tratti);
        T_model_vals = zeros(length(anni),1);
        
        for k = 1:length(anni)
            T_tgt_totale = T_target_tot(k);
            T_target_settori = pesi_settori * T_tgt_totale; % MI DICE QUANTO TEMPO PASSO IN OGNI TRATTO A PARTIRE DAL TEMPO STORICO
            v_guess = v_limits_ref * (sum(t_settori_mod) / T_tgt_totale);
            
            % CON QUESTO CALCOLO LE VELOCITA' OTTIMALI (MINIMI QUADRATI NON LINEARI)
            [v_limits_est_ms, ~, ~] = lsqnonlin(...
                @(v) compute_residuals(v, T_target_settori, x_acc, x_const, x_brake, m, k_aero, F_grip, ub_peak_ms), ...
                v_guess, lb_out, ub_out, options_out);
            
            % QUESTA FUNZIONE INVECE SERVE PER RUNNARE IL CODICE TENENDO
            % CONTO DI TUTTI I VINCOLI DEL PROBLEMA (INFATTI AL SUO INTERNO
            % RICHIAMA LE 2 FUNZIONI DEI CODICI PRECEDENTI)
            [t_calc_settori, ~] = simulate_sector_times(v_limits_est_ms, x_acc, x_const, x_brake, m, k_aero, F_grip, ub_peak_ms);
            
            % RICALCOLO LE VELOCITA' IN M/S E FACCIO LA SOMMA DEI TRE TEMPI
            % PER OGNI TRATTO PER AVERE POI IL TEMPO TOTALE 
            v_limits_history(k,:) = v_limits_est_ms' * 3.6;
            T_model_vals(k) = sum(t_calc_settori);
            
            err_pct = (T_model_vals(k) - T_tgt_totale)/T_tgt_totale * 100;
            fprintf('%-6d | %-12s | T_Tgt: %-8.3f | T_Calc: %-8.3f | Err: %+.4f%%\n',...
                anni(k), driver{k}, T_tgt_totale, T_model_vals(k), err_pct);
        end
        
        fprintf('\nVELOCITÀ DI INGRESSO CURVA STIMATE [km/h] PER ANNO\n');
        fprintf('%-6s ', 'Anno');
        for j=1:n_tratti, fprintf('%-12s', nomi_curva{j}); end
        fprintf('\n');
        fprintf(repmat('-',1, 6 + 12*n_tratti)); fprintf('\n');
        for k=1:length(anni)
            fprintf('%-6d ', anni(k));
            for j=1:n_tratti
                fprintf('%-12.1f', v_limits_history(k,j));
            end
            fprintf('\n');
        end
        
    case 2
        %% CASO 2: TEMPO PERSONALIZZATO
        fprintf('\n');
        tempo_input = input('Inserisci il tempo sul giro (es. "85.5" oppure "1:25.500"): ', 's');
        
        % VERIFICO IL TIPO DI INPUT PER IL TEMPO
        if contains(tempo_input, ':')
            parts = strsplit(tempo_input, ':');
            T_tgt_totale = str2double(parts{1})*60 + str2double(parts{2});
        else
            T_tgt_totale = str2double(tempo_input);
        end
        
        fprintf('\nCalcolo in corso per il tempo target di %.3f secondi...\n', T_tgt_totale);
        
        T_target_settori = pesi_settori * T_tgt_totale;
        v_guess = v_limits_ref * (sum(t_settori_mod) / T_tgt_totale); 
        
        [v_limits_est_ms, ~, ~] = lsqnonlin(...
            @(v) compute_residuals(v, T_target_settori, x_acc, x_const, x_brake, m, k_aero, F_grip, ub_peak_ms), ...
            v_guess, lb_out, ub_out, options_out);
        
        [t_calc_settori, v_peak_opt, t_acc_vec, t_const_vec, t_brk_vec] = ...
            simulate_sector_times_detailed(v_limits_est_ms, x_acc, x_const, x_brake, m, k_aero, F_grip, ub_peak_ms);

        v_limits_kmh  = v_limits_est_ms * 3.6;
        v_peak_kmh    = v_peak_opt * 3.6;
        T_calc_totale = sum(t_calc_settori);
        err_pct       = (T_calc_totale - T_tgt_totale) / T_tgt_totale * 100;
        fmt_time = @(s) sprintf('%d:%06.3f', floor(s/60), mod(s,60));

        %% ---- HEADER -------------------------------------------------------
        fprintf('\n');
        fprintf('╔═══════════════════════════════════════════════════════════════════════════════════════╗\n');
        fprintf('║          RISULTATI REVERSE ENGINEERING - CIRCUITO DI MONZA                            ║\n');
        fprintf('╠═══════════════════════════════════════════════════════════════════════════════════════╣\n');
        fprintf('║  Tempo Target   : %-10s  (%9.3f s)                                           ║\n', tempo_input, T_tgt_totale);
        fprintf('║  Tempo Calcolato: %-10s  (%9.3f s)   Errore: %+.4f%%                        ║\n', fmt_time(T_calc_totale), T_calc_totale, err_pct);
        fprintf('╚═══════════════════════════════════════════════════════════════════════════════════════╝\n');

        %% ---- TABELLA DETTAGLIATA PER TRATTO --------------------------------
        fprintf('\n');
        sep = repmat('─', 1, 105);
        fprintf('┌%s┐\n', sep);
        fprintf('│ %-13s │ %8s │ %10s │ %10s │ %10s │ %10s │ %10s │ %10s │\n', ...
            'Tratto', 'Dist.(m)', 'V_nodo(km/h)', 'V_peak(km/h)', 'T_acc(s)', 'T_const(s)', 'T_brake(s)', 'T_tot(s)');
        fprintf('├%s┤\n', sep);
        for j = 1:n_tratti
            fprintf('│ %-13s │ %8.2f │ %10.1f │ %10.1f │ %10.3f │ %10.3f │ %10.3f │ %10.3f │\n', ...
                nomi_curva{j}, L(j), v_limits_kmh(j), v_peak_kmh(j), ...
                t_acc_vec(j), t_const_vec(j), t_brk_vec(j), t_calc_settori(j));
        end
        fprintf('├%s┤\n', sep);
        fprintf('│ %-13s │ %8.2f │ %10s │ %10s │ %10.3f │ %10.3f │ %10.3f │ %10.3f │\n', ...
            'TOTALE', sum(L), '—', '—', ...
            sum(t_acc_vec), sum(t_const_vec), sum(t_brk_vec), T_calc_totale);
        fprintf('└%s┘\n', sep);

        %% ---- RIASSUNTO PERCENTUALI FASE ------------------------------------
        fprintf('\n');
        fprintf('┌────────────────────────────────────────────────────────┐\n');
        fprintf('│                  RIPARTIZIONE TEMPI                    │\n');
        fprintf('├────────────────────────────────────────────────────────┤\n');
        fprintf('│  Accelerazione  : %6.3f s  (%5.1f%% del giro)          │\n', sum(t_acc_vec),   sum(t_acc_vec)/T_calc_totale*100);
        fprintf('│  Velocità cost. : %6.3f s  (%5.1f%% del giro)          │\n', sum(t_const_vec), sum(t_const_vec)/T_calc_totale*100);
        fprintf('│  Frenata        : %6.3f s  (%5.1f%% del giro)          │\n', sum(t_brk_vec),   sum(t_brk_vec)/T_calc_totale*100);
        fprintf('└────────────────────────────────────────────────────────┘\n');

        %% ---- CONFRONTO CON RIFERIMENTO MODERNO ----------------------------
        fprintf('\n');
        fprintf('┌────────────────────────────────────────────────────────────────────┐\n');
        fprintf('│           CONFRONTO V_NODO vs RIFERIMENTO MODERNO                 │\n');
        fprintf('├──────────────────┬──────────────┬──────────────┬──────────────────┤\n');
        fprintf('│ Tratto           │  V_ref(km/h) │  V_est(km/h) │  Delta (km/h)    │\n');
        fprintf('├──────────────────┼──────────────┼──────────────┼──────────────────┤\n');
        for j = 1:n_tratti
            delta = v_limits_kmh(j) - v_limits_ref_kmh(j);
            fprintf('│ %-16s │ %12.1f │ %12.1f │ %+14.1f   │\n', ...
                nomi_curva{j}, v_limits_ref_kmh(j), v_limits_kmh(j), delta);
        end
        fprintf('└──────────────────┴──────────────┴──────────────┴──────────────────┘\n');
        fprintf('\n');

    otherwise
        fprintf('\nScelta non valida. Esegui nuovamente lo script e inserisci 1 o 2.\n');
end

%% ============================================================
% FUNZIONI DI SUPPORTO
% ============================================================

% È LA FUNZIONE OBIETTIVO PER LSQNONLIN.
% CALCOLA LA DIFFERENZA TRA I TEMPI DI SETTORE SIMULATI E I TEMPI DI
% SETTORE TARGET
function residuals = compute_residuals(v_lim_guess, T_target_settori, xa, xc, xb, m, k_aero, F_grip, ub_peak_ms)
    [t_settore, ~] = simulate_sector_times(v_lim_guess, xa, xc, xb, m, k_aero, F_grip, ub_peak_ms);
    residuals = t_settore - T_target_settori;
end

function [t_settore, v_peak_opt] = simulate_sector_times(v_lim, xa, xc, xb, m, k_aero, F_grip, ub_peak_ms)
    n_tratti = length(v_lim);
    % v_peak_0 clampato tra v_lim e ub_peak_ms per evitare lb > ub in fmincon
    v_peak_0 = min(v_lim + 5, ub_peak_ms);
    lb_in    = v_lim;
    ub_in    = ub_peak_ms;
    opts_in  = optimoptions('fmincon', 'Algorithm', 'sqp', 'Display', 'none');
    
    % RICHIAMO I VINCOLI FISICI PER TROVARE LE VELOCITA' PEAK
    [v_peak_opt, ~] = fmincon(@(v) obj_fissa(v, xa, xc, xb, v_lim), ...
        v_peak_0, [], [], [], [], lb_in, ub_in, ...
        @(v) const_fissa(v, xa, xb, m, k_aero, F_grip, v_lim), opts_in);
    
    t_settore = zeros(n_tratti, 1);
    v_in_val  = 0.1;
    % QUI STO CALCOLANDO I TEMPI DI ACC E CONST E LI SOMMO PER AVERE IL
    % TEMPO TOTALE (UTILIZZO LE V MEDIE)
    for i = 1:n_tratti
        vp = v_peak_opt(i); 
        vt = v_lim(i);
        t_acc   = xa(i) / ((v_in_val + vp)/2);
        t_const = xc(i) / vp;
        v_avg_brk = (vp + vt)/2;
        if v_avg_brk < 1e-3, v_avg_brk = 1e-3; end
        t_brk   = xb(i) / v_avg_brk;
        t_settore(i) = t_acc + t_const + t_brk;
        v_in_val = vt; 
    end
end

% RICEVONO IN IN. LE VELOCITA' ALLE CURVE (V_LIM) E CALCOLANO QUANTO TEMPO
% IMPIEGA L'AUTO A PERCORRERE I RETTILINEI
% RESTITUISCE I TEMPI PER SETTORE E LE VELOCITA' PEAK
function [t_settore, v_peak_opt, t_acc_vec, t_const_vec, t_brk_vec] = ...
        simulate_sector_times_detailed(v_lim, xa, xc, xb, m, k_aero, F_grip, ub_peak_ms)
    n_tratti = length(v_lim);
    % v_peak_0 clampato tra v_lim e ub_peak_ms per evitare lb > ub in fmincon
    v_peak_0 = min(v_lim + 5, ub_peak_ms);
    lb_in    = v_lim;
    ub_in    = ub_peak_ms;
    opts_in  = optimoptions('fmincon', 'Algorithm', 'sqp', 'Display', 'none');
    
    [v_peak_opt, ~] = fmincon(@(v) obj_fissa(v, xa, xc, xb, v_lim), ...
        v_peak_0, [], [], [], [], lb_in, ub_in, ...
        @(v) const_fissa(v, xa, xb, m, k_aero, F_grip, v_lim), opts_in);
    
    t_settore   = zeros(n_tratti, 1);
    t_acc_vec   = zeros(n_tratti, 1);
    t_const_vec = zeros(n_tratti, 1);
    t_brk_vec   = zeros(n_tratti, 1);
    v_in_val = 0.1; 
    for i = 1:n_tratti
        vp = v_peak_opt(i); 
        vt = v_lim(i);
        t_acc   = xa(i) / ((v_in_val + vp)/2);
        t_const = xc(i) / vp;
        v_avg_brk = (vp + vt)/2;
        if v_avg_brk < 1e-3, v_avg_brk = 1e-3; end
        t_brk   = xb(i) / v_avg_brk;
        t_acc_vec(i)   = t_acc;
        t_const_vec(i) = t_const;
        t_brk_vec(i)   = t_brk;
        t_settore(i)   = t_acc + t_const + t_brk;
        v_in_val = vt; 
    end
end

% QUESTA È LA FUNZIONE DA MINIMIZZARE
function T = obj_fissa(v_peak, xa, xc, xb, v_lim)
    T = 0; v_in = 0.1;
    for i = 1:length(v_peak)
        vp = v_peak(i); vt = v_lim(i);
        T = T + xa(i)/((v_in+vp)/2) + xc(i)/vp + xb(i)/((vp+vt)/2);
        v_in = vt;
    end
end

% APPLICA IL TEOREMA DEL DELL'ENERGIA CINETICA
function [c, ceq] = const_fissa(v_peak, xa, xb, m, k_aero, F_grip, v_lim)
    c = []; ceq = []; v_in = 0.1; 
    for i = 1:length(v_peak)
        vp = v_peak(i); vt = v_lim(i);
        F_net_acc = F_grip - k_aero * ((v_in+vp)/2)^2;
        c = [c; 0.5*m*(vp^2 - v_in^2) - F_net_acc*xa(i)];
        F_tot_brk = F_grip + k_aero * ((vp+vt)/2)^2;
        c = [c; 0.5*m*(vp^2 - vt^2) - F_tot_brk*xb(i)];
        v_in = vt;
    end
end