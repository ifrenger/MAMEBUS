%%%
%%% Reads in data from the output of 'Overturning' and makes a movie 
%%% of the solution.
%%%
%%% local_home_dir specifies the directory in the local system in which
%%% run files are stored. N.B. this function will search within a 
%%% subdirectory called 'run_name' to find the run's output files.
%%%
%%% run_name specifies the name of the run.
%%%
%%% If plot_strat is true then the density will be plotted, whereas if it
%%% is false then the streamfunction will be plotted.
%%%
%%% var_id Specifies the tracer number to plot (if plot_trac is true) or
%%% the streamfunction to plot (if plot_trac is false).
%%%
function filenames = plotSolution (local_home_dir,run_name,plot_trac,var_id,avgTime)

    %%% Load convenience functions
    addpath ../utils;
    addpath ./redblue

    mov_on = 0;
    mov_name = strcat(run_name,'_name');

    if var_id > 3
      disp('Plotting biogeochemistry solutions')
    end
    
    if (var_id > 3 && ~plot_trac)
        plot_trac = true;
        disp('You have chosen a variable which does not exist')
    end
    
    show_w = true; % plots vertical velocities

    %%%%%%%%%%%%%%%%%%%%%
    %%%%% VARIABLES %%%%%
    %%%%%%%%%%%%%%%%%%%%% 

    %%% Parameter and data file names
    run_name = strtrim(run_name);
    dirpath = fullfile(local_home_dir,run_name);
    params_file = fullfile(dirpath,[run_name,'_in']);  
    
    [dt_s dt_s_found] = readparam(params_file,'monitorFrequency','%f');
    [modeltype modeltype_found] = readparam(params_file,'bgcModel','%u');
    
    %%% Plotting grid
    [Nx Nx_found] = readparam(params_file,'Nx','%u');
    [Nz Nz_found] = readparam(params_file,'Nz','%u');
    [Lx Lx_found] = readparam(params_file,'Lx','%lf');
    [H H_found] = readparam(params_file,'Lz','%lf');
    if ((~Nx_found) || (~Nz_found) || (~Lx_found) || (~H_found))
    error('Could not read grid parameters');
    end    

    dx = Lx/Nx;
    %%% Read grid parameters
    [h_c h_c_found] = readparam(params_file,'h_c','%le');
    [theta_s theta_s_found] = readparam(params_file,'theta_s','%lf');
    [theta_b theta_b_found] = readparam(params_file,'theta_b','%lf');

    %%% Read bottom topography
    hb = readDataFile (params_file,dirpath,'topogFile',Nx+2,1,H*ones(Nx+2,1));
    hb_psi = 0.5*(hb(1:end-1)+hb(2:end));  
    hb_tr = hb(2:end-1); %%% Remove "ghost" points

    %%% Parameters related to number of iterations
    
    [startTime startTime_found] = readparam(params_file,'startTime','%lf');
    [endTime endTime_found] = readparam(params_file,'endTime','%lf'); 
    [restart restart_found] = readparam(params_file,'restart','%d');
    [n0 n0_found] = readparam(params_file,'startIdx','%u');

    %%% Default is that we're not picking up from a previous simulation
    if (~restart_found)
    restart = false;
    end

    %%% Default is that we pickup from the first output file
    if ((~restart) || (~n0_found))
    n0 = 0;
    end

    %%% If the start time isn't specified then it may be specified implicitly
    %%% by the pickup file
    if (~startTime_found)
    if (restart && dt_s_found)
      startTime = n0*dt_s;
    else
      startTime = 0;
    end
    end

    %%% For convenience
    t1year = 365*86400; %%% Seconds in one year
    t1day = 86400;

    dx = Lx/Nx; %%% Latitudinal grid spacing (in meters)
    xx_psi = 0:dx:Lx;

    %%% Generate full sigma-coordinate grids
    [XX_tr,ZZ_tr,XX_psi,ZZ_psi,XX_u,ZZ_u,XX_w,ZZ_w] ...
                        = genGrids(Nx,Nz,Lx,h_c,theta_s,theta_b,hb_tr,hb_psi);

    if (var_id ~= 0 && var_id ~= 1)
     n_var = var_id; 
    end
  
    %%% Max number of output files is the number of whole time steps that can
    %%% fit into tmax, plus one initial save, plus one final save
    Noutput = floor(endTime/dt_s) + 2;

    
    %%% Upload the names of the files in order to pick out the max N value
    A = dir(dirpath);
    M = size(A);
    M = floor(max(M)/6); % there are six output variables saved
                         % so this cuts down on the for loop.
    lastVal = 0;
    
    for ii = 1:M
        temp = A(ii).name;
        temp = strsplit(temp,'=');
        if max(size(temp) > 1)
            temp2 = char(temp(2));
            compVal = strsplit(temp2,'.');
            compVal = str2num(compVal{1});

            if compVal > lastVal
                lastVal = compVal;
            end
        end
    end
    
    
    %%% Pick out the last N value in the saved files. 
    outputFrac = dt_s/t1year;
    yearLength = 1/outputFrac; % Count the number of N values in one year.
    
    
%     avgTime = 10; % Choose the amount of time to average over (in years)
    LL = yearLength*avgTime;
    avgStart = round(lastVal - LL); % Calculate where we start the average.
    
    
    if avgStart < 1
        avgStart = 0;
    end
    
    ndt = 0;
    
    if (plot_trac)
        if (var_id == 0)
            title_name = 'Zonal Velocity';
        elseif (var_id == 1)
            title_name = 'Meridional Velocity';
        elseif (var_id == 2)
            title_name = 'Buoyancy';
        else
            % title names
            switch (modeltype)
                case 0
                    title_name = 'Depth Tracer';
                case 1 % nitrate only
                    if (var_id == 3)
                        title_name = 'Nitrate';
                    else
                        title_name = 'Depth Tracer';
                    end
                case 2 % npzd
                    if (var_id == 3)
                        title_name = 'Nitrate';
                    elseif (var_id == 4)
                        title_name = 'Phytoplankton';
                    elseif (var_id == 5)
                        title_name = 'Zooplankton';
                    elseif (var_id == 6)
                        title_name = 'Detritus';
                    elseif (var_id == 7)
                        title_name = 'Passive Tracer';
                    else
                        title_name = 'Depth Tracer';
                    end
                otherwise
                    title_name = 'Depth Tracer';
            end
        end
    else
        if (var_id == 0)
            title_name = 'Residual Streamfunction';
        elseif (var_id == 1)
            title_name = 'Mean Streamfunction';
        else 
            title_name = 'Eddy Streamfunction';
        end
    end
        
            
    
    
    disp(['Start time is ' num2str(avgStart*dt_s/t1year) ' yrs']);
    disp(['End time is ' num2str(lastVal*dt_s/t1year) ' yrs']);
    
    %%% Create a placeholder for avgVals
    if (plot_trac)
        avgVals = zeros(Nx,Nz);
        
        if (modeltype == 1 || modeltype == 2)
            avgUptake = zeros(Nx,Nz);
            
            %%% BGC parameters
            qsw = 340;
            kw = 0.04;
            I0 = 0.45*qsw;
            T0 = 20;
            r = 0.05;
            umax = 2.6;
            kpar = kw;
            
            %%% Light Profile.
            IR = I0*exp(kpar.*ZZ_tr);
            IR = IR./(sqrt(IR.^2 + I0.^2));
        end
    else
        avgVals = zeros(Nx+1,Nz+1);
    end
    
%     lastVal = 1200;
%     avgStart = lastVal - LL;
    
    tot = zeros(Nx,Nz);
    conserve = zeros(lastVal-avgStart,1);
    area = 0;
    CN = true;
    trac = 1;
    %%% Averaging loop
    for n = avgStart:lastVal
        if (plot_trac)
            data_file = fullfile(dirpath,['TRAC',num2str(var_id),'_n=',num2str(n),'.dat']);
            phi = readOutputFile(data_file,Nx,Nz);
            
            
            
            %%% calculate the uptake offline for the single nitrate bgc model
            if (modeltype == 2 && var_id == 4)
                buoy_id = 2;
                n_id = 3;
                data_file = fullfile(dirpath,['TRAC',num2str(n_id),'_n=',num2str(n),'.dat']);
                N = readOutputFile(data_file,Nx,Nz);
                buoy_file = fullfile(dirpath,['TRAC',num2str(buoy_id),'_n=',num2str(n),'.dat']);
                buoy = readOutputFile(data_file,Nx,Nz);
                r = 0.05;
                
%                 t_uptake = exp(r.*(buoy - T0*ones(Nx,Nz)));
                t_uptake = 1;
                umax = 0.1;
                uptake = umax.*t_uptake.*IR.*N;
                
                avgUptake = avgUptake + uptake;
            end
            
            

        else
            %%% Load different streamfunctions      
            switch (var_id)
                case 0 %%% Residual streamfunction
                    data_file = fullfile(dirpath,['PSIR_n=',num2str(n),'.dat']);
                case 1 %%% Mean streamfunction
                    data_file = fullfile(dirpath,['PSIM_n=',num2str(n),'.dat']);
                case 2 %%% Eddy streamfunction
                    data_file = fullfile(dirpath,['PSIE_n=',num2str(n),'.dat']);
            end
            
          %%% Get the psi values on the gridpoints
          phi = readOutputFile (data_file,Nx+1,Nz+1);
        end
        

        avgVals = avgVals + phi;
        ndt = ndt + 1;
    end
    
    avgVals = avgVals/ndt;
    
    Nmax = 30; %%% Maximum concentration of nutrient at the ocean bed
    Ncline = 250; % Approximate guess of the depth of the nutracline
    Ninit(:,:,1) = -Nmax*tanh(ZZ_tr./Ncline);


        
    %%% Plot the average values %%%
    timelengthstr = lastVal*dt_s/t1year - avgStart*dt_s/t1year;
    titlestr = [ title_name,' averaged over the final ', num2str(timelengthstr) , ' year(s)'];
    figure
    if (plot_trac)
        if (var_id == 0 || var_id == 1)
            pcolor(XX_tr,ZZ_tr,avgVals)
%             shading interp
            h = colorbar; 
            colormap redblue;
            maxspeed = 0;
            minval = max(max(max(avgVals)),maxspeed);
            minval = abs(min(min(min(avgVals)),-minval));
            caxis([-minval minval]);
            title(titlestr)
        elseif (var_id == 2) % plot buoyancy
            [C h] = contourf(XX_tr,ZZ_tr,avgVals,[0:1:20]);
            colorbar; 
            colormap default;
            title(titlestr)
            clabel(C,h,'Color','w');  
            set(h,'ShowText','on'); 
        else % plot biogeochemistry
%             [C h] = contourf(XX_tr,ZZ_tr,avgVals,[0:2:30]);
%             clabel(C,h,'Color','w');   
%             set(h,'ShowText','on'); 
            pcolor(XX_tr,ZZ_tr,avgVals);
            shading interp
            colorbar; 
            colormap jet;
            caxis([min(min(avgVals)) max(max(avgVals))])
%             caxis([0 0.11])
            title(titlestr)
            
            
        end
        
%         set(h,'FontSize',18);
        
        % Use a divergent colorscheme if we are looking at positive or
        % negative values
        if (var_id == 0 || var_id == 1)
            colormap redblue;
        end
    else
        psi_r_lim = avgVals;
        limval = 2;
        psi_r_lim = min(psi_r_lim,limval);
        psi_r_lim = max(psi_r_lim,-limval);
%       	contourf(XX_psi,ZZ_psi,psi_r_lim,[-2:0.5:2]); 
        pcolor(XX_psi,ZZ_psi,psi_r_lim)
        shading interp
        h = colorbar; 
        colormap redblue;
        caxis([-limval limval]);
        title(titlestr)
    end
    
    
    
%         title(titlestr)
%         hold on
%         plot(xx_psi,-hb_psi,'k')
%         hold off
%         set(h,'FontSize',18);

%     if (show_w)
%         avgVals = zeros(Nx+1,Nz+1);
%         wvel = zeros(Nx,Nz+1);
%         dx = Lx/Nx;
%         
%         for n = avgStart:lastVal
%             data_file = fullfile(dirpath,['PSIR_n=',num2str(n),'.dat']);
%             phi = readOutputFile (data_file,Nx+1,Nz+1);
%             for j = 1:Nx
%                 wvel(j,:) = (avgVals(j+1,:) - avgVals(j,:))/dx;
%             end
%             avgVals = avgVals + phi;
%         end
%         
%         % calculate the average of the residual stream function
%         avgVals = avgVals/ndt;
%         
%         
%         for j = 1:Nx
%             wvel(j,:) = (avgVals(j+1,:) - avgVals(j,:))/dx;
%         end
%         
%         figure
%         pcolor(XX_w,ZZ_w,wvel)
%         shading interp
%         colormap redblue;
%         colorbar
%         
%     end
        
        
        
    %%% TO DO: UPDATE FUNCTION TO INCLUDE VERTICAL VELOCITIES
end