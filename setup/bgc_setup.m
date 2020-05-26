%%% 
%%% bgc_setup.m
%%%
%%% Sets biogeochemical parameters to be used in MAMEBUS in the NPZD Model
%%%
%%% The initial values will be output as a matrix, and biogeochemical
%%% parameters are output as a vector to be read into the model. 
%%%


function [params, bgc_init, nbgc] = bgc_setup(ZZ_tr,Nx,Nz)

% parameters
lp = 5; % micrometers
lz = 10; 

%%% save all parameters
params = [lp, lz];
        
nbgc = length(params);


%%% Create initial conditions
Pcline = 200;
Pmax = 0.1; % mmol/m3
Dmax = 0;

euph_init = Pmax*(tanh(ZZ_tr/Pcline))+0.1;

%%% Initial nitrate profile (Hyperbolic)
Nmax = 30; %%% Maximum concentration of nutrient at the ocean bed
Ncline = 80; % Approximate guess of the depth of the nutracline


bgc_init(:,:,1) = -Nmax*tanh(ZZ_tr/Ncline);
bgc_init(:,:,2) = euph_init;
bgc_init(:,:,3) = 0.1*euph_init;
bgc_init(:,:,4) = Dmax*zeros(Nx,Nz);
end
