%% codice punto 1 COMMENTATO

%% OTTIMIZZAZIONE F1 MONZA - PUNTO 1 (MINIMO TEMPO)
% Obiettivi:
% - Il circuito è diviso in tratti.
% - In ogni tratto l'auto: accelera -> va costante -> frena.
% - Noi decidiamo quanto deve essere alta la velocità al nodo
% - Vogliamo minimizzare il tempo totale sul giro.
%
% Il problema viene risolto con fmincon (ottimizzazione con vincoli).

clear all; close all; clc;

%% 1) DATI DEL CIRCUITO (come da tabella / notebook)
% Lunghezze dei singoli tratti (metri)
L = [324.33, 458.00, 687.00, 412.00, 229.00, 229.00, 916.00, 916.00, 705.67, 916.00]';

% In ogni tratto: quanto accelero, quanto freno, quanto vado costante
x_brake = [122.0, 0.0, 0.0, 107.0, 0.0, 35.0, 50.0, 104.0, 76.0, 0.0]';
dist_frenata = 380;        % distanza di frenata
x_acc   = [202.33, dist_frenata, dist_frenata, 305.0, 229.0, 194.0, dist_frenata, dist_frenata, dist_frenata, dist_frenata]';
x_const = L - x_acc - x_brake; % quello che resta è la parte a velocità costante

%% 2) PARAMETRI FISICI (forze e limiti)
m = 620;         % massa auto [kg] 
k_aero = 0.387;  % coefficiente resistenza aerodinamica (R = k_aero * v^2)
mu = 4;          % coefficiente di aderenza
g = 9.81;        % gravità [m/s^2]
rho = 224.62;    % raggio di curvatura

% Velocità limite ai nodi (es. in curva non puoi superarla)
% Attenzione: sono in km/h nel vettore, poi convertite in m/s dividendo per 3.6
beta = sqrt(mu * rho * g)* 3.6 ;  % definito in m/s
v_limits_ms = [90; 315; 135; 195; 170; 325; 185; beta; beta; 360.0] / 3.6;

% Forza massima di aderenza gomme (grip): più è alta, più puoi accelerare/frenare
F_grip = mu * m * g;

%% 3) IMPOSTAZIONE DELL'OTTIMIZZAZIONE (fmincon)
n_tratti = length(L);            % quanti tratti abbiamo
v_peak_0 = v_limits_ms + 10;     % "tentativo iniziale": leggermente sopra i limiti

% Lower e Upper bound
lb = v_limits_ms;                    % non ha senso avere v_peak sotto la velocità limite in uscita
ub = ones(n_tratti, 1) * (360/3.6);  % limite massimo fisico 360 km/h
ub(8) = beta / 3.6; 
ub(9) = beta / 3.6; 

% Opzioni del solver
options = optimoptions('fmincon', 'Algorithm', 'sqp', 'Display', 'none');

%% Chiamata a fmincon:
% - vincoli: fisica di accelerazione/frenata
[v_peak_opt, T_total] = fmincon( ...
    @(v) obj_tempo(v, x_acc, x_const, x_brake, v_limits_ms), v_peak_0, [], [], [], [], lb, ub, ...
    @(v) vincoli_fisici(v, x_acc, x_brake, m, k_aero, F_grip, v_limits_ms), options);

%% 4) CALCOLO DEI TEMPI PER OGNI TRATTO
nomi_punti = {'Variante 1', 'Curva Grande', 'Roggia', 'Lesmo 1', 'Lesmo 2', ...
              'Serraglio', 'Ascari', 'Rett. Opposto', 'Parabolica', 'Traguardo'}';
t_acc   = zeros(n_tratti,1);
t_const = zeros(n_tratti,1);
t_brk   = zeros(n_tratti,1);

% v_in_val = velocità di ingresso nel tratto
% all'inizio del giro la mettiamo piccola per evitare divisioni per 0
v_in_val = 0.1;

for i = 1:n_tratti
    vp = v_peak_opt(i);     % velocità di picco scelta dall'ottimizzazione
    vt = v_limits_ms(i);    % velocità limite (uscita dal tratto)

    t_acc(i) = x_acc(i) / ((v_in_val + vp)/2);  % Tempo di accelerazione  (distanza / vel_media (media tra inizio e fine accel))
    t_const(i) = x_const(i) / vp;               % Tempo a velocità costante
    t_brk(i) = x_brake(i) / ((vp + vt)/2);      % Tempo di frenata

    v_in_val = vt; % La velocità di uscita di un tratto diventa la velocità di ingresso del tratto successivo
end
t_settore = t_acc + t_const + t_brk;

%% 5) STAMPA REPORT
fprintf('\n====================================================================================\n');
fprintf('                 REPORT MONZA - PUNTO 1 (SOLO TEMPO)                                 \n');
fprintf('====================================================================================\n');
fprintf('%-15s | %-8s | %-10s | %-6s | %-6s | %-6s | %-9s\n', ...
    'Settore', 'L [m]', 'Vpeak [km/h]', 't_acc', 't_cst', 't_brk', 'T_sett[s]');
fprintf('------------------------------------------------------------------------------------\n');

for i = 1:n_tratti
    fprintf('%-15s | %-8.1f | %-10.1f | %-6.2f | %-6.2f | %-6.2f | %-9.3f\n', ...
        nomi_punti{i}, L(i), v_peak_opt(i)*3.6, t_acc(i), t_const(i), t_brk(i), t_settore(i));
end

fprintf('------------------------------------------------------------------------------------\n');
fprintf('TEMPO TOTALE SUL GIRO: %.3f s\n', T_total);
fprintf('TOP SPEED RAGGIUNTA:   %.1f km/h\n', max(v_peak_opt)*3.6);
fprintf('VELOCITÀ MEDIA:        %.1f km/h\n', (sum(L)/T_total)*3.6);
fprintf('====================================================================================\n');

%% 6) GRAFICO VELOCITÀ vs DISTANZA
figure('Color', [0.1 0.1 0.1], 'Name', 'Telemetria - Punto 1');
ax = axes('Color', [0.15 0.15 0.15], 'XColor', 'w', 'YColor', 'w');
hold on; grid on;
ax.GridColor = [0.4 0.4 0.4];

curr_d = 0;      % distanza cumulativa
v_in_t = 0.1;    % velocità di ingresso corrente

for i = 1:n_tratti
    vp = v_peak_opt(i);
    vt = v_limits_ms(i);

    xa = x_acc(i); xc = x_const(i); xb = x_brake(i);

    % segmento verde: accelerazione
    plot([curr_d, curr_d+xa], [v_in_t, vp]*3.6, 'g', 'LineWidth', 2.5);

    % segmento bianco: costante
    plot([curr_d+xa, curr_d+xa+xc], [vp, vp]*3.6, 'w', 'LineWidth', 2.5);

    % segmento rosso: frenata
    plot([curr_d+xa+xc, curr_d+xa+xc+xb], [vp, vt]*3.6, 'r', 'LineWidth', 2.5);

    % linea verticale per separare i tratti
    line([curr_d+L(i), curr_d+L(i)], [0 400], 'Color', [0.4 0.4 0.4], 'LineStyle', ':');

    curr_d = curr_d + L(i);
    v_in_t = vt;
end

xlabel('Distanza [m]'); ylabel('Velocità [km/h]');
title(['Punto 1 - Lap Time: ', num2str(T_total, '%.3f'), ' s'], 'Color', 'w');

h = [plot(NaN,NaN,'g','LineWidth',2.5);
     plot(NaN,NaN,'w','LineWidth',2.5);
     plot(NaN,NaN,'r','LineWidth',2.5)];
legend(h, 'Accelerazione','Velocità Costante','Frenata', ...
       'TextColor', 'w', 'Color', [0.2 0.2 0.2], 'Location', 'best');


%% ===================== FUNZIONI LOCALI =====================

function T = obj_tempo(v_peak, xa, xc, xb, v_lim)
% Calcola il tempo totale sul giro (da minimizzare)
% Usa una velocità media nelle parti di accel/frenata

    T = 0;
    v_in = 0.1; % velocità di ingresso iniziale (piccola per sicurezza)

    for i = 1:length(v_peak)
        vp = v_peak(i);   % picco del tratto
        vt = v_lim(i);    % velocità limite a fine tratto

        T = T + xa(i)/((v_in+vp)/2) + xc(i)/vp + xb(i)/((vp+vt)/2);

        v_in = vt; % aggiorna ingresso tratto successivo
    end
end

function [c, ceq] = vincoli_fisici(v_peak, xa, xb, m, k_aero, F_grip, v_lim)
% Vincoli fisici (ineguaglianze):
% - l'energia richiesta per accelerare deve essere <= lavoro delle forze disponibili
% - stessa cosa per frenare
%
% fmincon vuole: c(v) <= 0

    c = [];
    ceq = [];

    v_in = 0.1;

    for i = 1:length(v_peak)
        vp = v_peak(i);
        vt = v_lim(i);

        % ----- ACCELERAZIONE -----
        % Energia cinetica specifica: 0.5*m*(vp^2 - v_in^2)
        % Forza netta disponibile = grip - drag
        F_net_acc = F_grip - k_aero * ((v_in+vp)/2)^2;

        % Vincolo: energia richiesta - lavoro disponibile <= 0
        c = [c; 0.5*m*(vp^2 - v_in^2) - F_net_acc*xa(i)];

        % ----- FRENATA -----
        % In frenata, drag aiuta (si somma al grip)
        F_tot_brk = F_grip + k_aero * ((vp+vt)/2)^2;

        c = [c; 0.5*m*(vp^2 - vt^2) - F_tot_brk*xb(i)];

        v_in = vt;
    end
end