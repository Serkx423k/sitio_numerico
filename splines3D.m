
clear; clc; close all;


%  1. Parametros del vuelo comercial;L


% Duracion total del vuelo en segundos, este es un vuelo corto
T_total = 7200;

% Numero de muestras de "datos GPS" (una cada ~30s)
N = 240;

% Fracciones de tiempo por fase (sobre T_total)
f_despegue  = 0.04;   % 0  - 4%   (~288s)
f_ascenso   = 0.18;   % 4% - 22%  (~1296s)
f_crucero   = 0.52;   % 22% - 74% (~3744s)
f_descenso  = 0.18;   % 74% - 92% (~1296s)
f_aterrizaje = 0.08;  % 92% - 100%(~576s)

% Altitudes por fase (metros)
alt_tierra    = 0;
alt_crucero   = 10500;   % ~35,000 ft tipico A320

% Velocidades horizontales por fase (km/h → m/s)
v_rotacion    = 280 / 3.6;   % velocidad de despegue
v_ascenso     = 450 / 3.6;
v_crucero     = 850 / 3.6;
v_descenso    = 500 / 3.6;
v_aterrizaje  = 240 / 3.6;

% Distancia horizontal total aproximada (~1500 km)
D_total = 1500e3;


%  2. PArametrizacion no unifoerme (t representa tiempo real)
%     Velocidad variable => dt no uniforme en espacio


% Definimos velocidad como función del tiempo normalizado s in [0,1]
s_norm = linspace(0, 1, N);

v_perfil = zeros(1, N);
for k = 1:N
    s = s_norm(k);
    if s < f_despegue
        p = s / f_despegue;
        v_perfil(k) = v_rotacion * p;                      % aceleración en pista
    elseif s < f_despegue + f_ascenso
        p = (s - f_despegue) / f_ascenso;
        v_perfil(k) = v_rotacion + (v_crucero - v_rotacion) * p;
    elseif s < f_despegue + f_ascenso + f_crucero
        % crucero con fluctuaciones por viento
        p = (s - f_despegue - f_ascenso) / f_crucero;
        v_perfil(k) = v_crucero + 20 * sin(2*pi*3*p) + 10 * sin(2*pi*7*p);
    elseif s < f_despegue + f_ascenso + f_crucero + f_descenso
        p = (s - f_despegue - f_ascenso - f_crucero) / f_descenso;
        v_perfil(k) = v_crucero - (v_crucero - v_descenso) * p;
    else
        p = (s - (1 - f_aterrizaje)) / f_aterrizaje;
        v_perfil(k) = v_aterrizaje * (1 - p);              % frenado en pista
    end
end

% Tiempo real acumulado por integración trapezoidal de 1/v
% d = v*dt  =>  dt = ds_distancia / v

distancia_acum = s_norm * D_total;
dt_approx = gradient(distancia_acum) ./ max(v_perfil, 1);
t_real = cumsum(dt_approx);
t_real = t_real / t_real(end) * T_total;   % normalizar a T_total


%  3. TRAYECTORIA HORIZONTAL (curva suave + ruta real)



% Curvatura lateral suave que simula ruta real
angulo_curva = linspace(0, pi/6, N);   % arco de ~30° total
radio_ruta   = D_total / (pi/6);

x = radio_ruta * sin(angulo_curva);
y = linspace(0, D_total * 0.15, N);    % desplazamiento Norte


%  4. Perfil de altitud por fase


z = zeros(1, N);
for k = 1:N
    s = s_norm(k);
    if s < f_despegue
        p = s / f_despegue;
        z(k) = alt_crucero * 0.03 * p;                   % rampa inicial corta
    elseif s < f_despegue + f_ascenso
        p = (s - f_despegue) / f_ascenso;
        % Ascenso con perfil sigmoide (más suave al inicio y al final)
        z(k) = alt_crucero * (3*p^2 - 2*p^3);
    elseif s < f_despegue + f_ascenso + f_crucero
        p = (s - f_despegue - f_ascenso) / f_crucero;
        % Crucero con ligeras variaciones de nivel de vuelo
        z(k) = alt_crucero + 150 * sin(2*pi*p) - 80 * sin(2*pi*2.3*p);
    elseif s < f_despegue + f_ascenso + f_crucero + f_descenso
        p = (s - f_despegue - f_ascenso - f_crucero) / f_descenso;
        z(k) = alt_crucero * (1 - (3*p^2 - 2*p^3)) + 300 * (1 - p);
    else
        p = (s - (1 - f_aterrizaje)) / f_aterrizaje;
        z(k) = 300 * (1 - p);
    end
end

%  5. Ruido realista
%    - Ruido GPS (blanco, pequeño)
%  - Turbulencia armónica (mayor en crucero, escalonada p or fase)


rng(42);   % semilla para reproducibilidad

% Amplitudes de turbulencia por fase (metros)
amp_turb_xy = zeros(1, N);
amp_turb_z  = zeros(1, N);
for k = 1:N
    s = s_norm(k);
    if s < f_despegue
        amp_turb_xy(k) = 5;  amp_turb_z(k) = 2;
    elseif s < f_despegue + f_ascenso
        amp_turb_xy(k) = 40; amp_turb_z(k) = 15;
    elseif s < f_despegue + f_ascenso + f_crucero
        amp_turb_xy(k) = 80; amp_turb_z(k) = 30;   % CAT en crucero
    elseif s < f_despegue + f_ascenso + f_crucero + f_descenso
        amp_turb_xy(k) = 40; amp_turb_z(k) = 15;
    else
        amp_turb_xy(k) = 5;  amp_turb_z(k) = 2;
    end
end

% Turbulencia de Dryden (suma de armónicos con fases aleatorias)
freq1 = 0.15; freq2 = 0.37; freq3 = 0.71;
phi = rand(1, 6) * 2 * pi;   % fases aleatorias

turb_x = amp_turb_xy .* (0.5*sin(2*pi*freq1*s_norm + phi(1)) + ...
                          0.3*sin(2*pi*freq2*s_norm + phi(2)) + ...
                          0.2*sin(2*pi*freq3*s_norm + phi(3)));

turb_y = amp_turb_xy .* (0.5*sin(2*pi*freq1*s_norm + phi(4)) + ...
                          0.3*sin(2*pi*freq2*s_norm + phi(5)) + ...
                          0.2*sin(2*pi*freq3*s_norm + phi(6)));

turb_z = amp_turb_z  .* (0.6*sin(2*pi*freq2*s_norm + phi(1)+1) + ...
                          0.4*sin(2*pi*freq3*s_norm + phi(3)+2));

% Ruido GPS (10m horizontal, 5m vertical)
ruido_gps_xy = 10;
ruido_gps_z  = 5;

x_datos = x + ruido_gps_xy*randn(1,N) + turb_x;
y_datos = y + ruido_gps_xy*randn(1,N) + turb_y;
z_datos = z + ruido_gps_z *randn(1,N) + turb_z;

% Asegurar que no haya altitudes negativas
z_datos = max(z_datos, 0);


%  Spline cubico 3D

t_eval = linspace(t_real(1), t_real(end), 1500);

[coefX, coefY, coefZ, xs, ys, zs] = spline_cubico3D(t_real, x_datos, y_datos, z_datos, t_eval);


%  Visualización


% Colores por fase para la curva del spline
s_eval = linspace(0, 1, length(t_eval));
colores_fase = zeros(length(t_eval), 3);
for k = 1:length(t_eval)
    s = s_eval(k);
    if s < f_despegue
        colores_fase(k,:) = [0.95 0.60 0.10];   % naranja - despegue
    elseif s < f_despegue + f_ascenso
        colores_fase(k,:) = [0.20 0.60 0.90];   % azul - ascenso
    elseif s < f_despegue + f_ascenso + f_crucero
        colores_fase(k,:) = [0.15 0.75 0.50];   % verde - crucero
    elseif s < f_despegue + f_ascenso + f_crucero + f_descenso
        colores_fase(k,:) = [0.60 0.40 0.90];   % morado - descenso
    else
        colores_fase(k,:) = [0.90 0.30 0.30];   % rojo - aterrizaje
    end
end

figure('Name','Datos GPS con ruido y turbulencia','Color','w');
scatter3(x_datos/1e3, y_datos/1e3, z_datos, 18, z_datos, 'filled');
colormap(gca, parula);
colorbar; cb = colorbar; cb.Label.String = 'Altitud (m)';
grid on; axis tight;
xlabel('X (km)'); ylabel('Y (km)'); zlabel('Altitud (m)');
title('Datos GPS: nube de puntos con turbulencia y ruido', 'FontSize', 13);
view(45, 25);


figure('Name','Spline cúbico 3D - Vuelo comercial','Color','w');
hold on;

% Puntos de datos
scatter3(x_datos/1e3, y_datos/1e3, z_datos, 15, [0.7 0.7 0.7], 'filled', 'DisplayName','GPS + turbulencia');

% Spline coloreado por fase (dibujado segmento a segmento)
for k = 1:length(t_eval)-1
    plot3([xs(k) xs(k+1)]/1e3, [ys(k) ys(k+1)]/1e3, [zs(k) zs(k+1)], ...
        '-', 'Color', colores_fase(k,:), 'LineWidth', 2.0);
end

% Nodos de control
scatter3(x_datos/1e3, y_datos/1e3, z_datos, 35, 'k', 'o', 'LineWidth', 1.2, 'DisplayName','Nodos spline');


p1 = patch(NaN,NaN,[0.95 0.60 0.10]); p1.DisplayName='Despegue';
p2 = patch(NaN,NaN,[0.20 0.60 0.90]); p2.DisplayName='Ascenso';
p3 = patch(NaN,NaN,[0.15 0.75 0.50]); p3.DisplayName='Crucero';
p4 = patch(NaN,NaN,[0.60 0.40 0.90]); p4.DisplayName='Descenso';
p5 = patch(NaN,NaN,[0.90 0.30 0.30]); p5.DisplayName='Aterrizaje';

legend([p1 p2 p3 p4 p5], 'Location','northwest');
grid on; axis tight;
xlabel('X (km)'); ylabel('Y (km)'); zlabel('Altitud (m)');
title('Trayectoria de vuelo comercial — Spline cúbico 3D por fases', 'FontSize', 13);
view(45, 25);

% --- Figura 3: Perfil de altitud vs tiempo ---
figure('Name','Perfil de altitud y velocidad','Color','w');

subplot(2,1,1);
plot(t_eval/60, zs, 'b-', 'LineWidth', 2); hold on;
plot(t_real/60, z_datos, 'r.', 'MarkerSize', 5);
xlabel('Tiempo (min)'); ylabel('Altitud (m)');
title('Perfil de altitud: spline vs datos GPS');
legend('Spline cúbico','Datos GPS+ruido');
grid on;

subplot(2,1,2);
plot(t_real/60, v_perfil*3.6, 'k-', 'LineWidth', 2);
xlabel('Tiempo (min)'); ylabel('Velocidad (km/h)');
title('Perfil de velocidad por fase');
yline(850, '--r', 'Crucero 850 km/h');
grid on;



function [coef, S_eval] = spline_cubico2(x_data, y_data, x_eval)
    % Spline cúbico natural: sistema 4n x 4n
    % S_j(x) = a_j + b_j(x-x_j) + c_j(x-x_j)^2 + d_j(x-x_j)^3

    n = length(x_data) - 1;
    A = zeros(4*n);
    b = zeros(4*n, 1);
    row = 1;

    % S_j(x_j) = y_j
    for j = 0:n-1
        A(row, 4*j+(1:4)) = [1 0 0 0];
        b(row) = y_data(j+1);
        row = row + 1;
    end

    % S_j(x_{j+1}) = y_{j+1}
    for j = 0:n-1
        h = x_data(j+2) - x_data(j+1);
        A(row, 4*j+(1:4)) = [1 h h^2 h^3];
        b(row) = y_data(j+2);
        row = row + 1;
    end

    % Continuidad C1: S'_j(x_{j+1}) = S'_{j+1}(x_{j+1})
    for j = 0:n-2
        h = x_data(j+2) - x_data(j+1);
        A(row, 4*j+(1:4))     = [0  1  2*h  3*h^2];
        A(row, 4*(j+1)+(1:4)) = [0 -1  0    0    ];
        b(row) = 0;
        row = row + 1;
    end

    % Continuidad C2: S''_j(x_{j+1}) = S''_{j+1}(x_{j+1})
    for j = 0:n-2
        h = x_data(j+2) - x_data(j+1);
        A(row, 4*j+(1:4))     = [0  0  2   6*h];
        A(row, 4*(j+1)+(1:4)) = [0  0 -2   0  ];
        b(row) = 0;
        row = row + 1;
    end

    % Condiciones naturales: S''_0(x_0) = 0 y S''_{n-1}(x_n) = 0
    A(row, 3) = 2;
    b(row) = 0;
    row = row + 1;

    h_last = x_data(end) - x_data(end-1);
    A(row, 4*(n-1)+(3:4)) = [2  6*h_last];
    b(row) = 0;

    % Resolver sistema
    u = A \ b;

    % Organizar coeficientes [a b c d] por intervalo
    coef = zeros(n, 4);
    for j = 0:n-1
        coef(j+1,:) = u(4*j+(1:4)).';
    end

    % Evaluar spline
    S_eval = zeros(size(x_eval));
    for k = 1:length(x_eval)
        xk = x_eval(k);
        if xk <= x_data(1)
            j = 0;
        elseif xk >= x_data(end)
            j = n - 1;
        else
            j = find(x_data <= xk, 1, 'last') - 1;
            j = max(0, min(j, n-1));
        end
        a  = coef(j+1,1);  b1 = coef(j+1,2);
        c  = coef(j+1,3);  d  = coef(j+1,4);
        xj = x_data(j+1);
        S_eval(k) = a + b1*(xk-xj) + c*(xk-xj)^2 + d*(xk-xj)^3;
    end
end

function [coefX, coefY, coefZ, xs, ys, zs] = spline_cubico3D(t, x, y, z, t_eval)
    [coefX, xs] = spline_cubico2(t, x, t_eval);
    [coefY, ys] = spline_cubico2(t, y, t_eval);
    [coefZ, zs] = spline_cubico2(t, z, t_eval);
end