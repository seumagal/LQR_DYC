%{
---------------------------------------------------------------------------
  Criador: Zo� Magalh�es (zr.magal@gmail.com)
  Mestrando do PPMEC-Unb, matr�cula 170172767
  Disciplina: Controle Preditivo 01/2018
  Professor: Andr� Murilo
  
  Este script executa uma simula��o para o controle de estabilidade lateral 
  veicular mediante aplica��o LQR,
  com perturba��o mensur�vel (entrada n�o controlada) e restri��es
  para os estados e sinal de controle.
%}

clear 
%% Configura��o

    %Horizonte de predi��o
    simlinear = [];
    openloop = 0;
    Ts = 8e-5; %Per�odo de amostragem
    
    % Manobra de+ teste
    maneuver = 'doublelane'; %'doublelane'
    max_steer = 10*pi/180;

%% Par�metros do modelo
    a                   =  1.1;  %dist�ncia entre cg e eixo frontal
    b                   =  1.3;  %dist�ncia entre cg e eixo traseiropl
    tf                  =  1.4;   %comprimento do eixo frontal
    tr                  =  1.41;   %comprimento do eixo traseiro
    hg                  =  0.6;  %altura do cg
    m                   =  1070; %massa
    hs                  =  0.55;  %altura do centro de rolagem
    ms                  =  900; %massaa sobre centro de rolagem
    kf					=  65590;  %coeficiente de rigidez frontal a rolagem
    kr 					=  65590;  %coeficiente de rigidez traseira a rolagem
    cf					=  2100;   %coeficiente de amortecimento frontal a rolagem
    cr 					=  2100;   %coeficiente de amortecimental traseiro a rolagem
    roll_damping        =  cf+cr;   %coeficiente de rigidez a rolagem
    roll_stiffness      =  kf+kr;   %coeficiente de amortecimento a rolagem
    Izz                 =  2100;  %momento de in�rcia do eixo de guinada
    Ixx                 =  500;     %momento de in�rcia do eixo de rolagem
    Ixz                 =  47.5;      %produto de in�rcia dos eixos de rolagem e guinada
    g                   =  9.80665 ;    %acelera��o gravitacional
    l = a+b;                       %dist�ncia entre os eixos frontal e traseiro       
    uspeed = 80/3.6;               %velociade longitudinal de lineariza��o
    MFA                 = [ 1.6  ,-34 , 1250 ,  2320  , 12.8 ,     0 , -0.0053 , 0.1925         ];
 	MFB                 = [ 1.55 ,0   , 1000 ,   60  , 300  , 0.17 , 0      , 0      ,0.2 ];
	Reff                 = 0.307;

    C_alpha = MFA(4)*sind( 2*atand( ([b,b,a,a]*m*g/(2000*l))/MFA(5) ) )*180/pi;    
    Ku = m*(b*C_alpha(3) - a*C_alpha(2))/(l*C_alpha(1)*C_alpha(3));
    %Ku = 0.06;  %Coeficiente utilizado para calcular a taxa de guinada desejada

    l = a+b;
	pneumatic_trail     = 0;
	u = 80/3.6;
	friction_coefficient = 0.9;
    J = 1;
    Ts = 8e-5;
    
	eta = m*Ixx*Izz - m*Ixz*Ixz - ms*ms*hs*hs*Izz;
    

	d(1) = ms*hs*Izz;
	d(2) = m*Ixz;
	d(3) = m*Izz*ms*hs*g;
	d(4) = m*Izz*roll_stiffness;
	d(5) = m*Izz*roll_damping;
	d(1:5) = d(1:5)/eta;
	d(6) = 1/Izz;
	d(7) = Ixz/Izz;
	d(8) = 1/m;
    d(9) = 1;
    d(10) = ms*hs/m;
	d(11) = 1/m;
	d(12) = ms*hs/m;
	d(13) = 1;

	zf0 = m*g*b/(2*l);
	zr0 = m*g*a/(2*l);
	z(1) = m*hg*b/(2*l);
	z(2) = m*hg/(l*tf);
	z(3) = kf/tf;
	z(4) = cf/tf;
	z(5) = kr/tr;
	z(6) = cr/tr;
	z(7) = m*hg*a/(2*l);
	tf2 = tf/2;
    tr2 = tr/2;
    C_1 = 4;
    M_1 = 0.5;
    M_2 = 0.5;
    GAMMA = 8;    
    
    %states_max = [14.55 23.80 0.35 0.01 0.02]
    %states_min = [-12.31 6.18 -0.26 -0.01 -0.02];
    dac_max = [3  ,17 , 0.5 , 0.2 , 0.2 ,1.5]
    dac_min = [-7 ,5  ,-1.5 ,-0.4 ,-0.4 ,-3];

	params = [MFA,MFB,z,zf0,zr0,a,b,tf2,tr2,d,Reff,J];
    
%% Modelo simlinear Mx'= A1x + B1u + E1steer
    M1 = [      m*uspeed,    0,  -ms*hs,  0;
                       0,  Izz,    -Ixz,  0;
                -ms*hs*uspeed, -Ixz,     Ixx,  roll_damping;
                       0,    0,       0,  1 ];

    A1 = [-sum(C_alpha)         , -(C_alpha*[a;a;-b;-b]/uspeed) - m*uspeed  , 0  , 0;
          -C_alpha*[a;a;-b;-b]  , -C_alpha*[a*a;a*a;b*b;b*b]/uspeed              , 0  , 0;
            0                   ,  ms*hs*uspeed                           , 0  , (ms*hs*g-roll_stiffness);
            0                   , 0                                       , 1  , 0 ];

    B1 = [0; 1; 0; 0];  

    E1 = [ C_alpha*[1;1;0;0]; C_alpha*[a;a;0;0];0;0 ];

%% Modelo espa�o de estado: x` = Ax + Bu + Esteer y'= Cx + Du
    A = M1\A1;
    B = M1\B1;
    C = eye(size(A));
    E = M1\E1;
    D = zeros(size(B));
	
    Q = diag([0.001,1,0.001,0.001]);
	R = 1e-10;
	LQRopt = lqrd(A,B,Q,R,8e-5)
    
    sys = ss( A,B,C,D);
    d_sys =c2d(sys,8e-5)
    
    abs(eig(d_sys.a))

    clear sys
    clear d_sys

    %% Carrega os sinais para o ester�amento das rodas dianteiras
    switch maneuver 
        case 'fishhook'
        load simin;
        disp('fishhook')
        steer = simin(1:8:300001,:);

        case 'doublelane'
        load dlcinput;
        disp('doublelane')
        steer = dlcinput;
        steer(:,1) = steer(:,1);

        otherwise
            disp('entrada nao implementada')

    end

    steer(:,2) = steer(:,2)*max_steer;

    save modelParam
    
