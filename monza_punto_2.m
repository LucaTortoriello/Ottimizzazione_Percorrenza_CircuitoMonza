%% codice punto 2 COMMENTATO

%% PROGETTO 7 - PUNTO 2: OTTIMIZZAZIONE (TEMPO + CONSUMO)
% Obiettivi:
% - Come nel punto 1 minimizziamo il tempo.
% - Però aggiungiamo anche il consumo di carburante.
% - Il consumo cresce con v^2 (se vai più forte, consumi molto di più).
% - Obiettivo: J = Tempo + W_consumo * Consumo

clear all; close all; clc;

%% 1) DATI CIRCUITO
L = [324.33, 458.00, 687.00, 412.00, 229.00, 229.00, 916.00, 916.00, 705.67, 916.00]';

x_brake = [122.0, 0.0, 0.0, 107.0, 0.0, 35.0, 50.0, 104.0, 76.0, 0.0]';
dist_frenata = 380;        % distanza di frenata
x_acc   = [202.33, dist_frenata, dist_frenata, 305.0, 229.0, 194.0, dist_frenata, dist_frenata, dist_frenata, dist_frenata]';
x_const = L - x_acc - x_brake;

%% 2) PARAMETRI FISICI
m = 722;
g = 9.81;

k_aero = 0.387;

mu = 3.2;
F_grip = mu * m * g;
rho = 224.62;

% Parametro consumo epsilon
epsilon = 6e-6;

beta = sqrt(mu * rho * g) * 3.6;  % definito in m/s (NOTA: qui moltiplichi per 3.6, poi dividi dopo)
v_limits_ms = [90; 315; 135; 195; 170; 325; 185; beta; beta; 360.0] / 3.6;

%% 3) PESO CONSUMO
% W_consumo dice: "Quanto mi importa risparmiare benzina?"
% - 0 = voglio solo andare forte (qualifica, punto 1)
% - grande = accetto di perdere tempo per consumare meno
W_consumo = 1;      % es: accetto di perdere tempo per ridurre consumo

%% 4) OTTIMIZZAZIONE fmincon
n_tratti = length(L);

v_peak_0 = v_limits_ms + 10;
lb = v_limits_ms;
ub = ones(n_tratti, 1) * (360/3.6);

% Obiettivo: Tempo + W * Consumo
[v_peak_opt, Costo_Totale] = fmincon( ...
    @(v) obj_ibrida(v, x_acc, x_const, x_brake, v_limits_ms, W_consumo, epsilon), ...
    v_peak_0, [], [], [], [], lb, ub, ...
    @(v) vincoli_fisici(v, x_acc, x_brake, m, k_aero, F_grip, v_limits_ms));

%% 5) RICALCOLO TEMPO E CONSUMO PER STAMPARE REPORT
nomi_punti = {'Variante 1', 'Curva Grande', 'Roggia', 'Lesmo 1', 'Lesmo 2', ...
              'Serraglio', 'Ascari', 'Rett. Opposto', 'Parabolica', 'Traguardo'}';

t_settore = zeros(n_tratti,1);
c_settore = zeros(n_tratti,1);

v_in_val = 0.1;

for i = 1:n_tratti
    vp = v_peak_opt(i);
    vt = v_limits_ms(i);

    % ---- TEMPO ----
    ta = x_acc(i)   / ((v_in_val + vp)/2);
    tc = x_const(i) / vp;
    tb = x_brake(i) / ((vp + vt)/2);
    t_settore(i) = ta + tc + tb;

    % ---- CONSUMO ----
    % Convertiamo in km/h perché la formula del progetto spesso è pensata così nel testo
    v_a_kmh = ((v_in_val + vp)/2) * 3.6;   % accel (velocità media)
    v_c_kmh = vp * 3.6;                    % costante
    v_b_kmh = ((vp + vt)/2) * 3.6;         % frenata (media)

    % consumi (distanze in km)
    ca = epsilon * (v_a_kmh^2) * (x_acc(i)/1000);
    cc = epsilon * (v_c_kmh^2) * (x_const(i)/1000);
    cb = epsilon * (v_b_kmh^2) * (x_brake(i)/1000);

    c_settore(i) = ca + cc + cb;

    v_in_val = vt;
end

T_total = sum(t_settore);
Consumo_Giro = sum(c_settore);



%% 6) STAMPA REPORT
fprintf('\n========================================================================================\n');
fprintf('                 REPORT MONZA - PUNTO 2 (TEMPO + CONSUMO)   W = %g\n', W_consumo);
fprintf('========================================================================================\n');
fprintf('%-15s | %-8s | %-10s | %-10s | %-10s\n', ...
    'Settore', 'L [m]', 'Vpeak [km/h]', 'Tempo [s]', 'Consumo [L]');
fprintf('----------------------------------------------------------------------------------------\n');

for i = 1:n_tratti
    fprintf('%-15s | %-8.1f | %-10.1f | %-10.3f | %-10.4f\n', ...
        nomi_punti{i}, L(i), v_peak_opt(i)*3.6, t_settore(i), c_settore(i));
end

fprintf('----------------------------------------------------------------------------------------\n');
fprintf('TEMPO TOTALE SUL GIRO: %.3f s\n', T_total);
fprintf('CONSUMO PER GIRO:      %.4f L\n', Consumo_Giro);
fprintf('CONSUMO GARA (53 giri):%.2f L\n', Consumo_Giro * 53);
%% 5bis) CONTROLLO VINCOLO CARBURANTE GARA (53 giri <= 145 L)
fuel_limit = 145;          % [L] limite massimo disponibile in gara
n_giri = 53;

Consumo_Gara = Consumo_Giro * n_giri;

if Consumo_Gara > fuel_limit + 1e-9   % tolleranza numerica
    fprintf('\n[WARNING] Limite carburante NON rispettato!\n');
    fprintf('          Consumo gara stimato: %.2f L  >  Limite: %.2f L\n', Consumo_Gara, fuel_limit);
    fprintf('          Aumenta W_consumo per penalizzare il consumo e ridurre la velocità ottima.\n');
else
    fprintf('\nLimite carburante rispettato: %.2f L <= %.2f L\n', Consumo_Gara, fuel_limit);
end
fprintf('========================================================================================\n');

%% ===================== FUNZIONI LOCALI =====================

function J = obj_ibrida(v_peak, xa, xc, xb, v_lim, W, eps)
% Obiettivo totale da minimizzare:
% J = Tempo + W * Consumo

    T = 0; % tempo totale
    C = 0; % consumo totale
    v_in = 0.1;

    for i = 1:length(v_peak)
        vp = v_peak(i);
        vt = v_lim(i);

        % --- TEMPO ---
        T = T + xa(i)/((v_in+vp)/2) + xc(i)/vp + xb(i)/((vp+vt)/2);

        % --- CONSUMO (proporzionale a v^2) ---
        v_a_kmh = ((v_in+vp)/2) * 3.6;
        v_c_kmh = vp * 3.6;
        v_b_kmh = ((vp+vt)/2) * 3.6;

        ca = eps * (v_a_kmh^2) * (xa(i)/1000);
        cc = eps * (v_c_kmh^2) * (xc(i)/1000);
        cb = eps * (v_b_kmh^2) * (xb(i)/1000);

        C = C + ca + cc + cb;

        v_in = vt;
    end

    % costo complessivo
    J = T + W * C;
end

function [c, ceq] = vincoli_fisici(v_peak, xa, xb, m, k_aero, F_grip, v_lim)
% Gli stessi vincoli fisici del punto 1.
% c <= 0

    c = [];
    ceq = [];

    v_in = 0.1;

    for i = 1:length(v_peak)
        vp = v_peak(i);
        vt = v_lim(i);

        % Accelerazione: grip - drag
        F_net_acc = F_grip - k_aero * ((v_in+vp)/2)^2;
        c = [c; 0.5*m*(vp^2 - v_in^2) - F_net_acc*xa(i)];

        % Frenata: grip + drag
        F_tot_brk = F_grip + k_aero * ((vp+vt)/2)^2;
        c = [c; 0.5*m*(vp^2 - vt^2) - F_tot_brk*xb(i)];

        v_in = vt;
    end
end

