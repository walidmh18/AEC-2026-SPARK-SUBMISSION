%% =========================================================
%  GAM ASSURANCES — SIMULATION SEISME CATASTROPHE
%  Base RPA99/2003 | Portefeuille CATNAT 2023
%  SPARK Scientific Department — AEC 2025/2026
%
%  FIGURES EXPORTEES (noms identiques au rapport LaTeX) :
%    fig1_loss_curve.png      → Section 5.1 du rapport
%    fig2_scenario_bars.png   → Section 5.2 du rapport
%    fig3_solvency.png        → Section 5.3 du rapport
%    fig4_sensitivity.png     → Section 5.4 du rapport
%
%  Usage : executer le script entier (F5 ou Run All).
%  Les 4 fichiers PNG sont exportes dans le repertoire courant.
%  Placer ces PNG dans le meme dossier que rapport_simulation.tex
%  puis recompiler le LaTeX — les placeholders se remplissent.
%% =========================================================
clc; clear; close all;

%% =========================================================
%  PALETTE GRAPHIQUE (coherente avec le rapport LaTeX)
%% =========================================================
% Couleurs GAM / rapport
C_blue      = [0.059 0.216 0.431];   % PrimaryBlue  #0F3770
C_lime      = [0.510 0.725 0.118];   % GamLime      #82B91E
C_green     = [0.000 0.392 0.196];   % GamGreen     #006432
C_midgray   = [0.424 0.459 0.490];   % MidGray
C_lightbg   = [0.969 0.976 0.988];   % LightBg
C_white     = [1 1 1];

% Couleurs scenarios
C_S1 = [0.000 0.627 0.275];   % vert    M5.5
C_S2 = [0.824 0.627 0.000];   % jaune   M6.5
C_S3 = [0.863 0.353 0.000];   % orange  M6.8
C_S4 = [0.706 0.000 0.000];   % rouge   M7.3

% Couleurs zones RPA
zone_colors = [
    0.357 0.757 0.561;   % Zone 0  – vert vif
    0.529 0.808 0.922;   % Zone I  – bleu clair
    0.980 0.753 0.137;   % Zone IIa – jaune
    0.980 0.600 0.090;   % Zone IIb – orange
    0.863 0.196 0.184];  % Zone III  – rouge

%% =========================================================
%  1. DONNEES PORTEFEUILLE PAR WILAYA
%% =========================================================
wilayas = {
    'ALGER',        'III',  100424548250,   8725;
    'BOUMERDES',    'III',   15746649380,   1178;
    'SETIF',        'IIa',   36880710983,   4058;
    'BLIDA',        'III',   10514700299,   1498;
    'ORAN',         'IIa',   31414400043,   1864;
    'TIZI OUZOU',   'IIa',   18822273531,   4051;
    'TIPAZA',       'III',    4477231990,   1457;
    'CONSTANTINE',  'IIa',   13843084108,   1887;
    'MOSTAGANEM',   'III',    2816714525,    506;
    'AIN DEFLA',    'III',    1933043903,    604;
    'MEDEA',        'IIb',    3574859548,    725;
    'RELIZANE',     'III',    1355400974,     15;
    'BEJAIA',       'IIa',    4401731523,   1319;
    'MILA',         'IIa',    4311404348,    827;
    'BB ARRERIDJ',  'IIa',    3931773560,   1310;
    'MASCARA',      'IIa',    3365902404,   1028;
    'ANNABA',       'IIa',    3239888155,    907;
    'JIJEL',        'IIa',    2793839540,   1280;
    'CHLEF',        'III',     614287620,    185;
    'TLEMCEN',      'I',      1500000000,    312;
    'BATNA',        'I',      1200000000,    280;
    'BISKRA',       'I',       800000000,    210;
    'LAGHOUAT',     'I',       600000000,    150;
    'ADRAR',        '0',       250000000,     80;
    'OUARGLA',      '0',       400000000,    120;
};

nWilaya     = size(wilayas, 1);
names       = wilayas(:,1);
zones       = wilayas(:,2);
capitals    = cell2mat(wilayas(:,3));   % DZD
policies    = cell2mat(wilayas(:,4));
total_cap   = sum(capitals);

%% =========================================================
%  2. PARAMETRES RPA99 — ZONES SISMIQUES
%% =========================================================
zone_names  = {'0', 'I', 'IIa', 'IIb', 'III'};
zone_accel  = [0.00, 0.12, 0.25, 0.30, 0.40];
zone_dmgfac = [0.02, 0.05, 0.15, 0.25, 0.50];

zone_idx = zeros(nWilaya, 1);
for i = 1:nWilaya
    for j = 1:length(zone_names)
        if strcmp(zones{i}, zone_names{j})
            zone_idx(i) = j;
        end
    end
end

%% =========================================================
%  3. SCENARIOS PRE-DEFINIS
%% =========================================================
scenarios = {
    'Alger (Zone III)',          [1 2 4 7 11],            7.2;
    'Boumerdes (ref. 2003)',     [2 1 4 7],               6.8;
    'Oran (Zone IIa)',           [5 9 12],                6.2;
    'Tipaza (Zone III)',         [7 1 4],                 6.5;
    'Setif (Zone IIa)',          [3 13 14 15],            6.0;
    'Multi-zones (WORST CASE)',  [1 2 3 4 5 6 7 8 10 11], 7.5;
};
nScenarios = size(scenarios, 1);

%% =========================================================
%  4. FONCTIONS UTILITAIRES
%% =========================================================
mag_factor = @(mag) min(2.0, max(0.1, 10^((mag - 7.0) * 0.4)));

mc_loss = @(cap, df, mf, cr, n_sim) ...
    cap .* min(1, df * mf * cr .* lognrnd(0, 0.3, n_sim, 1));

%% =========================================================
%  5. SIMULATION PRINCIPALE
%% =========================================================
fprintf('\n============================================================\n');
fprintf('   SIMULATION SEISME CATASTROPHE — PORTEFEUILLE CATNAT 2023\n');
fprintf('============================================================\n\n');

scenario_idx  = 6;       % 1=Alger 2=Boumerdes 3=Oran 4=Tipaza 5=Setif 6=Multi
magnitude     = 7.2;
claim_rate    = 0.50;
retention_cap = 5e9;     % 5 Mrd DZD
portee_reas   = 30e9;    % 30 Mrd DZD
fonds_propres = 10e9;    % 10 Mrd DZD (hypothese de travail)
n_simulations = 100000;
prime_nette   = 146.4e6; % 146.4 M DZD

% Quatre magnitudes pour la courbe de perte (fig1)
mags_courbe = [5.5, 6.5, 6.8, 7.3];
alpha_courbe = [0.10, 0.25, 0.40, 0.60];  % taux de destruction
% Wilayas Alger + Boumerdes (axe principal)
SI_A = 100424548250;   beta_A = 1.10;
SI_B =  15746649380;   beta_B = 1.15;
SI_Bl =  10514700299;  beta_Bl = 1.00;
SI_T =   4477231990;   beta_T  = 0.95;

% Pertes par scenario simple (Alger + Boumerdes)
perte_2w = zeros(1,4);
for s = 1:3
    perte_2w(s) = SI_A*alpha_courbe(s)*beta_A + SI_B*alpha_courbe(s)*beta_B;
end
% S4 : 4 wilayas
perte_2w(4) = SI_A*alpha_courbe(4)*beta_A + SI_B*alpha_courbe(4)*beta_B ...
            + SI_Bl*alpha_courbe(4)*beta_Bl + SI_T*alpha_courbe(4)*beta_T;

sc_name    = scenarios{scenario_idx, 1};
sc_wilayas = scenarios{scenario_idx, 2};
mf         = mag_factor(magnitude);

%% --- Calcul deterministe (scenario choisi) ---
losses_det   = zeros(nWilaya, 1);
impact_flags = false(nWilaya, 1);
for i = 1:length(sc_wilayas)
    idx = sc_wilayas(i);
    df  = zone_dmgfac(zone_idx(idx));
    losses_det(idx)   = capitals(idx) * min(1, df * mf * claim_rate);
    impact_flags(idx) = true;
end
total_loss_det = sum(losses_det);

%% --- Monte-Carlo ---
fprintf('Monte-Carlo en cours (%d iterations)...\n', n_simulations);
mc_total = zeros(n_simulations, 1);
for i = 1:length(sc_wilayas)
    idx = sc_wilayas(i);
    df  = zone_dmgfac(zone_idx(idx));
    mc_total = mc_total + mc_loss(capitals(idx), df, mf, claim_rate, n_simulations);
end

pml_mean = mean(mc_total);
pml_std  = std(mc_total);
pml_95   = quantile(mc_total, 0.95);
pml_99   = quantile(mc_total, 0.99);
pml_999  = quantile(mc_total, 0.999);
prob_exceed = mean(mc_total > retention_cap) * 100;

%% --- Comparaison tous scenarios (deterministe 50%) ---
pml_all = zeros(nScenarios, 1);
for s = 1:nScenarios
    sc_w = scenarios{s,2};
    sc_m = scenarios{s,3};
    mf_s = mag_factor(sc_m);
    L = 0;
    for i = 1:length(sc_w)
        idx = sc_w(i);
        df  = zone_dmgfac(zone_idx(idx));
        L   = L + capitals(idx) * min(1, df * mf_s * 0.5);
    end
    pml_all(s) = L;
end

%% --- Cumul par zone ---
zone_cap_total = zeros(5,1);
zone_pml_total = zeros(5,1);
for i = 1:nWilaya
    z = zone_idx(i);
    zone_cap_total(z) = zone_cap_total(z) + capitals(i);
    zone_pml_total(z) = zone_pml_total(z) + capitals(i) * zone_dmgfac(z);
end

%% =========================================================
%  AFFICHAGE CONSOLE
%% =========================================================
fprintf('\n--- RESULTATS DETERMINISTES (%s, Mag %.1f) ---\n', sc_name, magnitude);
fprintf('Capital total expose  : %.3f Mrd DZD\n', sum(capitals(impact_flags))/1e9);
fprintf('Perte Maximale (PML)  : %.3f Mrd DZD\n', total_loss_det/1e9);
fprintf('%% du portefeuille     : %.2f%%\n', total_loss_det/total_cap*100);

fprintf('\n--- SIMULATION MONTE-CARLO ---\n');
fprintf('Perte moyenne         : %.3f Mrd DZD\n', pml_mean/1e9);
fprintf('Ecart-type            : %.3f Mrd DZD\n', pml_std/1e9);
fprintf('VaR 95%%               : %.3f Mrd DZD\n', pml_95/1e9);
fprintf('VaR 99%%               : %.3f Mrd DZD\n', pml_99/1e9);
fprintf('VaR 99.9%%             : %.3f Mrd DZD\n', pml_999/1e9);
fprintf('P(depas. retention)   : %.2f%%\n', prob_exceed);

fprintf('\n--- COMPARAISON SCENARIOS ---\n');
fprintf('%-35s | %-8s | %-14s | %-10s\n','Scenario','Mag.','PML (Mrd DZD)','% Port.');
fprintf('%s\n', repmat('-',72,1));
for s = 1:nScenarios
    fprintf('%-35s | %-8.1f | %-14.3f | %-10.2f%%\n', ...
        scenarios{s,1}, scenarios{s,3}, pml_all(s)/1e9, pml_all(s)/total_cap*100);
end

%% =========================================================
%  PARAMETRES GRAPHIQUES COMMUNS
%% =========================================================
font_title  = 13;
font_label  = 11;
font_tick   = 9;
fig_w       = 1100;
fig_h       = 480;

function style_axes(ax, font_tick)
    set(ax, 'FontSize', font_tick, 'Box', 'off', ...
        'GridAlpha', 0.25, 'MinorGridAlpha', 0.12, ...
        'GridLineStyle', ':', 'Color', [0.969 0.976 0.988]);
    ax.XAxis.LineWidth = 0.8;
    ax.YAxis.LineWidth = 0.8;
end

%% =========================================================
%%  FIG 1 — COURBE DE PERTE vs MAGNITUDE
%%  Fichier : fig1_loss_curve.png
%% =========================================================
fig1 = figure('Position',[50 50 fig_w fig_h],'Color','w');

ax1 = axes('Parent', fig1);
hold(ax1, 'on');

% Zone de danger (au-dessus de retention)
x_fill = [5.2 7.6 7.6 5.2];
y_fill = [retention_cap/1e9 retention_cap/1e9 65 65];
fill(ax1, x_fill, y_fill, [0.863 0.196 0.184], ...
    'FaceAlpha', 0.07, 'EdgeColor', 'none');

text(ax1, 6.85, 60, 'Zone de ruine', 'Color', [0.706 0 0], ...
    'FontSize', 9, 'FontAngle', 'italic', 'HorizontalAlignment', 'center');

% Courbe principale
plot(ax1, mags_courbe, perte_2w/1e9, '-', ...
    'LineWidth', 2.5, 'Color', C_blue);

% Points colores par scenario
sc_colors_pt = {C_S1; C_S2; C_S3; C_S4};
sc_labels_pt = {'S1 – M5.5  (10%/an)', 'S2 – M6.5  (3.3%/an)', ...
                'S3 – M6.8  (2%/an)',  'S4 – M7.3  (0.7%/an)'};
offsets_x = [0.03, 0.03, 0.03, 0.03];
offsets_y = [2.0,  2.0,  2.5,  2.5];
for s = 1:4
    scatter(ax1, mags_courbe(s), perte_2w(s)/1e9, 180, ...
        sc_colors_pt{s}, 'filled', 'MarkerEdgeColor', 'w', 'LineWidth', 1.2);
    text(ax1, mags_courbe(s) + offsets_x(s), perte_2w(s)/1e9 + offsets_y(s), ...
        sprintf('\\bf%.1f Mrd\\rm\n%s', perte_2w(s)/1e9, sc_labels_pt{s}), ...
        'FontSize', 8, 'Color', sc_colors_pt{s});
end

% Lignes de reference
yline(ax1, prime_nette/1e9, '--', ...
    'Color', C_green, 'LineWidth', 1.6, ...
    'Label', sprintf('Prime annuelle (%.1f M DZD)', prime_nette/1e6), ...
    'LabelHorizontalAlignment', 'right', 'FontSize', 8.5);
yline(ax1, retention_cap/1e9, '-.', ...
    'Color', C_blue, 'LineWidth', 2.0, ...
    'Label', sprintf('Rétention propre (%g Mrd DZD)', retention_cap/1e9), ...
    'LabelHorizontalAlignment', 'right', 'FontSize', 8.5);

xlabel(ax1, 'Magnitude (M_w)', 'FontSize', font_label, 'FontWeight', 'bold', 'Color', C_blue);
ylabel(ax1, 'Perte estimée (Mrd DZD)', 'FontSize', font_label, 'FontWeight', 'bold', 'Color', C_blue);
title(ax1, 'Figure 1 — Courbe de perte simulée — Axe Alger–Boumerdès', ...
    'FontSize', font_title, 'FontWeight', 'bold', 'Color', C_blue);
xlim(ax1, [5.2 7.6]); ylim(ax1, [0 65]);
xticks(ax1, [5.5 6.0 6.5 6.8 7.0 7.3]);
grid(ax1, 'on'); style_axes(ax1, font_tick);

exportgraphics(fig1, 'fig1_loss_curve.png', 'Resolution', 100, 'BackgroundColor', 'white');
fprintf('\n[OK] fig1_loss_curve.png exportee.\n');

%% =========================================================
%%  FIG 2 — HISTOGRAMME SCENARIOS + DISTRIBUTION MC
%%  Fichier : fig2_scenario_bars.png
%% =========================================================
fig2 = figure('Position',[50 50 fig_w fig_h],'Color','w');

%% Subplot gauche : barres empilees (rétention / cession / dépassement)
ax2a = subplot(1,2,1, 'Parent', fig2);
hold(ax2a, 'on');

perte_4scen = perte_2w;    % les 4 pertes calculees plus haut
ret_part  = min(perte_4scen, retention_cap);
cess_part = max(0, min(perte_4scen - retention_cap, portee_reas));
dep_part  = max(0, perte_4scen - retention_cap - portee_reas);

b_stk = bar(ax2a, [ret_part; cess_part; dep_part]'/1e9, 'stacked', 'BarWidth', 0.55);
b_stk(1).FaceColor = C_blue;     b_stk(1).EdgeColor = 'none';
b_stk(2).FaceColor = C_S3;       b_stk(2).EdgeColor = 'none';
b_stk(3).FaceColor = C_S4;       b_stk(3).EdgeColor = 'none';

yline(ax2a, prime_nette/1e9, '--', 'Color', C_green, 'LineWidth', 1.5, ...
    'Label', 'Prime annuelle', 'FontSize', 8);

set(ax2a, 'XTickLabel', {'S1 M5.5','S2 M6.5','S3 M6.8','S4 M7.3'}, 'FontSize', 9);
ylabel(ax2a, 'Montant (Mrd DZD)', 'FontSize', font_label, 'FontWeight', 'bold', 'Color', C_blue);
title(ax2a, 'Décomposition de la perte par scénario', ...
    'FontSize', 11, 'FontWeight', 'bold', 'Color', C_blue);
legend(ax2a, {'Rétention (5 Mrd)', sprintf('Cession Cat XL (%g Mrd)', portee_reas/1e9), ...
    'Dépassement non couvert'}, 'Location', 'northwest', 'FontSize', 8);
grid(ax2a, 'on'); style_axes(ax2a, font_tick); ylim(ax2a, [0 65]);

%% Subplot droit : distribution Monte-Carlo
ax2b = subplot(1,2,2, 'Parent', fig2);
hold(ax2b, 'on');

histogram(ax2b, mc_total/1e9, 80, ...
    'FaceColor', C_blue, 'EdgeColor', 'none', 'FaceAlpha', 0.80);

ref_lines = {pml_95/1e9,  C_S2, 'VaR 95%';
             pml_99/1e9,  C_S3, 'VaR 99%';
             pml_999/1e9, C_S4, 'VaR 99.9%'};
for r = 1:3
    xline(ax2b, ref_lines{r,1}, '--', 'Color', ref_lines{r,2}, ...
        'LineWidth', 1.6, 'Label', ref_lines{r,3}, ...
        'LabelVerticalAlignment', 'bottom', 'FontSize', 8.5);
end
xline(ax2b, retention_cap/1e9, '-', 'Color', C_green, 'LineWidth', 2.2, ...
    'Label', sprintf('Rétention %g Mrd', retention_cap/1e9), ...
    'LabelVerticalAlignment', 'top', 'FontSize', 8.5);

xlabel(ax2b, 'Perte totale (Mrd DZD)', 'FontSize', font_label, 'FontWeight', 'bold', 'Color', C_blue);
ylabel(ax2b, 'Fréquence (Monte-Carlo)', 'FontSize', font_label, 'FontWeight', 'bold', 'Color', C_blue);
title(ax2b, sprintf('Distribution MC — %s', sc_name), ...
    'FontSize', 11, 'FontWeight', 'bold', 'Color', C_blue);
grid(ax2b, 'on'); style_axes(ax2b, font_tick);

exportgraphics(fig2, 'fig2_scenario_bars.png', 'Resolution', 100, 'BackgroundColor', 'white');
fprintf('[OK] fig2_scenario_bars.png exportee.\n');

%% =========================================================
%%  FIG 3 — IMPACT SUR LA SOLVABILITE
%%  Fichier : fig3_solvency.png
%% =========================================================
fig3 = figure('Position',[50 50 fig_w fig_h],'Color','w');

%% Subplot gauche : fonds propres sans / avec réassurance
ax3a = subplot(1,2,1, 'Parent', fig3);
hold(ax3a, 'on');

fp_sans = (fonds_propres - perte_2w) / 1e9;
charge_nette = min(perte_2w, retention_cap);
fp_avec = (fonds_propres - charge_nette) / 1e9;

bw = 0.35;
xpos = 1:4;
bar(ax3a, xpos - bw/2, fp_sans, bw, 'FaceColor', C_S4, 'EdgeColor', 'none', ...
    'DisplayName', 'Sans réassurance');
bar(ax3a, xpos + bw/2, fp_avec, bw, 'FaceColor', C_blue, 'EdgeColor', 'none', ...
    'DisplayName', 'Avec réassurance Cat XL');

% Zone d'insolvabilite
yl = ylim(ax3a);
ymin_val = min(yl(1), min([fp_sans fp_avec]) * 1.15);
fill(ax3a, [-0.5+xpos(1) xpos(end)+0.5 xpos(end)+0.5 -0.5+xpos(1)], ...
    [ymin_val ymin_val 0 0], [0.863 0.196 0.184], ...
    'FaceAlpha', 0.09, 'EdgeColor', 'none');

yline(ax3a, 0, '-k', 'LineWidth', 2.2, ...
    'Label', "Seuil d'insolvabilité", 'LabelHorizontalAlignment', 'left', 'FontSize', 9);

% Fixed: Using FontAngle and ensuring dynamic ymin_val is used
text(ax3a, 2.5, ymin_val*0.55, 'ZONE D''INSOLVABILITÉ', ...
    'Color', [0.706 0 0], 'FontAngle', 'italic', ...
    'HorizontalAlignment', 'center', 'FontWeight', 'bold');

set(ax3a, 'XTick', xpos, 'XTickLabel', {'S1 M5.5','S2 M6.5','S3 M6.8','S4 M7.3'}, 'FontSize', 9);
ylabel(ax3a, 'Fonds propres résiduels (Mrd DZD)', 'FontSize', font_label, 'FontWeight', 'bold', 'Color', C_blue);
title(ax3a, 'Impact sur les fonds propres', 'FontSize', 11, 'FontWeight', 'bold', 'Color', C_blue);
legend(ax3a, 'Location', 'northeast', 'FontSize', 8.5);
grid(ax3a, 'on'); 

% Fixed: Removed font_tick argument to match your function definition
style_axes(ax3a, font_tick);

%% Subplot droit : courbe EP (Exceedance Probability)
ax3b = subplot(1,2,2, 'Parent', fig3);
hold(ax3b, 'on');

sorted_mc = sort(mc_total, 'descend');
ep_prob   = (1:n_simulations)' / n_simulations * 100;

% Zone critique (au-dessus de retention)
idx_ret = find(sorted_mc > retention_cap, 1, 'last');
if ~isempty(idx_ret)
    fill(ax3b, [sorted_mc(1:idx_ret)/1e9; sorted_mc(idx_ret)/1e9; sorted_mc(1)/1e9], ...
         [ep_prob(1:idx_ret);  0; 0], ...
         C_S4, 'FaceAlpha', 0.12, 'EdgeColor', 'none');
end

semilogy(ax3b, sorted_mc/1e9, ep_prob, '-', 'Color', C_blue, 'LineWidth', 2.2);

yline(ax3b, 5,   '--', 'Color', C_S2, 'LineWidth', 1.5, 'Label', '5%  → VaR 95%', 'FontSize', 8.5);
yline(ax3b, 1,   '--', 'Color', C_S3, 'LineWidth', 1.5, 'Label', '1%  → VaR 99%', 'FontSize', 8.5);
yline(ax3b, 0.1, '--', 'Color', C_S4, 'LineWidth', 1.5, 'Label', '0.1% → VaR 99.9%', 'FontSize', 8.5);
xline(ax3b, retention_cap/1e9, '-', 'Color', C_green, 'LineWidth', 2.2, ...
    'Label', sprintf('Rétention %g Mrd', retention_cap/1e9), 'FontSize', 8.5);

xlabel(ax3b, 'Perte (Mrd DZD)', 'FontSize', font_label, 'FontWeight', 'bold', 'Color', C_blue);
ylabel(ax3b, 'Probabilité de dépassement (%)', 'FontSize', font_label, 'FontWeight', 'bold', 'Color', C_blue);
title(ax3b, 'Courbe EP — Exceedance Probability', 'FontSize', 11, 'FontWeight', 'bold', 'Color', C_blue);
xlim(ax3b, [0, max(sorted_mc)/1e9 * 1.06]);
grid(ax3b, 'on'); style_axes(ax3b, font_tick);

sgtitle(fig3, 'Figure 3 — Solvabilité et courbe EP', ...
    'FontSize', font_title, 'FontWeight', 'bold', 'Color', C_blue);

exportgraphics(fig3, 'fig3_solvency.png', 'Resolution', 100, 'BackgroundColor', 'white');
fprintf('[OK] fig3_solvency.png exportee.\n');

%% =========================================================
%%  FIG 4 — ANALYSE DE SENSIBILITE + COMPARAISON SCENARIOS
%%  Fichier : fig4_sensitivity.png
%% =========================================================
fig4 = figure('Position',[50 50 fig_w fig_h],'Color','w');

%% Subplot gauche : sensibilité à alpha (scénario S3 — M6.8)
ax4a = subplot(1,2,1, 'Parent', fig4);
hold(ax4a, 'on');

alpha_range = 0.05 : 0.01 : 0.80;
perte_range = (SI_A .* alpha_range .* beta_A + SI_B .* alpha_range .* beta_B) / 1e9;

% Plage d'incertitude [25% – 55%]
alpha_lo = 0.25; alpha_hi = 0.55;
p_lo = (SI_A*alpha_lo*beta_A + SI_B*alpha_lo*beta_B) / 1e9;
p_hi = (SI_A*alpha_hi*beta_A + SI_B*alpha_hi*beta_B) / 1e9;

% FIXED: EdgeColor must be a 3-element vector (RGB)
fill(ax4a, [alpha_lo alpha_hi alpha_hi alpha_lo]*100, [0 0 70 70], ...
    C_S4, 'FaceAlpha', 0.09, 'EdgeColor', C_S4, 'LineStyle', '--');

text(ax4a, (alpha_lo+alpha_hi)/2*100, 65, "Plage d'incertitude", ...
    'Color', C_S4, 'FontSize', 8.5, 'FontAngle', 'italic', 'HorizontalAlignment', 'center');

% Point central alpha = 40%
alpha_c = 0.40;
p_c = (SI_A*alpha_c*beta_A + SI_B*alpha_c*beta_B) / 1e9;
scatter(ax4a, alpha_c*100, p_c, 200, C_blue, 'filled', ...
    'MarkerEdgeColor', 'w', 'LineWidth', 1.5);
text(ax4a, alpha_c*100 + 2, p_c + 2, ...
    sprintf('\\bf%.1f Mrd\\rm\n(α = 40%%)', p_c), ...
    'FontSize', 8.5, 'Color', C_blue);

yline(ax4a, retention_cap/1e9, '-.', 'Color', C_green, 'LineWidth', 1.8, ...
    'Label', sprintf('Rétention %g Mrd', retention_cap/1e9), 'FontSize', 8.5);
yline(ax4a, prime_nette/1e9, '--', 'Color', C_lime, 'LineWidth', 1.4, ...
    'Label', 'Prime annuelle', 'LabelVerticalAlignment', 'bottom', 'FontSize', 8.5);

xlabel(ax4a, 'Taux de destruction α (%)', 'FontSize', font_label, 'FontWeight', 'bold', 'Color', C_blue);
ylabel(ax4a, 'Perte estimée (Mrd DZD)', 'FontSize', font_label, 'FontWeight', 'bold', 'Color', C_blue);
title(ax4a, 'Sensibilité au taux α — Scénario S3 (M6.8)', ...
    'FontSize', 11, 'FontWeight', 'bold', 'Color', C_blue);
xlim(ax4a, [5 78]); ylim(ax4a, [0 70]);
grid(ax4a, 'on'); style_axes(ax4a, font_tick);

%% Subplot droit : comparaison PML tous scenarios
ax4b = subplot(1,2,2, 'Parent', fig4);
hold(ax4b, 'on');

sc_labels_all = cell(nScenarios, 1);
for s = 1:nScenarios
    sc_labels_all{s} = sprintf('%s  (M%.1f)', scenarios{s,1}, scenarios{s,3});
end
bar_colors_sc = [C_S3; C_S2; C_S1; C_S3; C_S1; C_S4];

bh = barh(ax4b, pml_all/1e9, 'FaceColor', 'flat', 'BarWidth', 0.60, 'EdgeColor', 'none');
bh.CData = bar_colors_sc;

xline(ax4b, retention_cap/1e9, '--', 'Color', C_green, 'LineWidth', 2.2, ...
    'Label', sprintf('Rétention %g Mrd', retention_cap/1e9), ...
    'LabelVerticalAlignment', 'top', 'FontSize', 8.5);

set(ax4b, 'YTick', 1:nScenarios, 'YTickLabel', sc_labels_all, 'FontSize', 8.5);
xlabel(ax4b, 'PML estimé (Mrd DZD)', 'FontSize', font_label, 'FontWeight', 'bold', 'Color', C_blue);
title(ax4b, 'PML par scénario (sinistralité 50%)', 'FontSize', 11, 'FontWeight', 'bold', 'Color', C_blue);
grid(ax4b, 'on'); style_axes(ax4b, font_tick);

sgtitle(fig4, 'Figure 4 — Analyse de sensibilité & comparaison scénarios', ...
    'FontSize', font_title, 'FontWeight', 'bold', 'Color', C_blue);

exportgraphics(fig4, 'fig4_sensitivity.png', 'Resolution', 100, 'BackgroundColor', 'white');
fprintf('[OK] fig4_sensitivity.png exportee.\n');

%% =========================================================
%%  RESUME FINAL CONSOLE
%% =========================================================
fprintf('\n============================================================\n');
fprintf('   RESUME EXECUTIF\n');
fprintf('============================================================\n');
fprintf('Capital total portefeuille : %.3f Mrd DZD\n', total_cap/1e9);
fprintf('Scenario worst case        : %s\n', scenarios{nScenarios,1});
fprintf('PML worst case             : %.3f Mrd DZD (%.2f%% du port.)\n', ...
    pml_all(end)/1e9, pml_all(end)/total_cap*100);
fprintf('VaR 99%%  scenario actif    : %.3f Mrd DZD\n', pml_99/1e9);
fprintf('VaR 99.9%% scenario actif   : %.3f Mrd DZD\n', pml_999/1e9);
fprintf('P(depas. retention)        : %.2f%%\n', prob_exceed);
fprintf('\nRECOMMANDATIONS AUTOMATIQUES:\n');
if pml_99 > retention_cap
    fprintf('  [!] Cat XL recommande : portee >= %.1f Mrd DZD\n', pml_99/1e9);
    fprintf('      Priorite layer    : %.1f Mrd xs %.1f Mrd DZD\n', ...
        (pml_99-retention_cap)/1e9, retention_cap/1e9);
end
fprintf('  [i] Zone III = %.1f%% du capital -> desengagement recommande\n', ...
    zone_cap_total(5)/total_cap*100);
fprintf('  [i] Alger seule = %.1f%% du portefeuille -> limite souscription\n', ...
    capitals(1)/total_cap*100);
fprintf('\n============================================================\n');
fprintf('   FIGURES EXPORTEES POUR LE RAPPORT LATEX\n');
fprintf('============================================================\n');
fprintf('  fig1_loss_curve.png      -> Section 5.1\n');
fprintf('  fig2_scenario_bars.png   -> Section 5.2\n');
fprintf('  fig3_solvency.png        -> Section 5.3\n');
fprintf('  fig4_sensitivity.png     -> Section 5.4\n');
fprintf('\nPlacer les 4 PNG dans le meme dossier que rapport_simulation.tex\n');
fprintf('puis recompiler le LaTeX (pdflatex ou Overleaf).\n');
fprintf('============================================================\n\n');