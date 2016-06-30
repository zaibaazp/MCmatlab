function heatSim

% Heat sim
% The purpose of this program is to simulate
% the heating of illuminated tissue.
% This program uses the light distribution and tissue structure from 
% maketissue_example2.m, makeTissueList.m, and lookmcxyz.m by importing
% HeatSimIn.mat

directoryPath='./Data/';

load([directoryPath 'Input_spectrum'])

%% Setup of simulation 
q = 0;
for fluence = F_min:dF:F_max
    q = q+1;
    num = num2str(q);
    load([directoryPath 'HeatSimIn_blood4_' num '.mat'])

    %% Simulation Parameters
    %%% Parameters to set %%%
    save_name           = ['HeatSimOut_blood4_' num '.mat'];
    pulse_energy_area   = fluence; % [J/cm^2] pulse energy per area
    pulse_duration      = pulse; % [s] pulse duration
    duration_after      = 10e-3; % [s] simulation duration after pulse
    dt                  = 5e-5; % timestep size, should be on the order of or less,
                                %than the smallest value of dx^2*HC/TC (characteristic timescale for heat diffusion in individual voxels
                                % also the pulse duration should be divisible by dt
    Temp_initial        = 36; % initial temperature of tissue  

    % switches
    save_on     = 1; % 1 to save output, 0 otherwise
    Apcal       = 1; % 1 to simulate the time during illumination, 0 otherwise
    postcal     = 1; % 1 to simulate the time after illumination, 0 otherwise
    quick_cal   = 1; % 1 to calculate only on a smaller matrix, 0 otherwise

    %% Parameters that is set automatically
    tissueList  = makeTissueList(nm); %Properties of the tissue types
    Temp        = Temp_initial*ones(400,400,400); % initial temperature in Celsius

    % Matrices contaning the thermal properties of the tissue
    HC = zeros(size(T));
    TC = zeros(size(T));
    for tissueNumber=1:length(tissueList)
        HC(T==tissueNumber) = tissueList(tissueNumber).HC;
        TC(T==tissueNumber) = tissueList(tissueNumber).TC;
    end

    % miscellaneous constants
    area            = (Nx*dx)^2; % surface area of the model
    pulse_energy    = pulse_energy_area*area; % [J] energy delivered to the volume
    Wdel            = pulse_energy/pulse_duration; % Watt delivered
    Nt_light        = round(pulse_duration/dt); % Number of timesteps with illumination
    Nt_no_light     = round(duration_after/dt); % Numer of timesteps with no illumination 

    % Due to the way photons leaving the matrix is handled in mcxyz.c, the Ap
    % values on the borders are much too large, therefore they will be set to
    % zero
    Ap(1:Nx,1:Ny,1)     = 0;
    Ap(1:Nx,1:Ny,Nz)    = 0;
    Ap(1:Nx,1,1:Nz)     = 0;
    Ap(1:Nx,Ny,1:Nz)    = 0;
    Ap(1,1:Ny,1:Nz)     = 0;
    Ap(Nx,1:Ny,1:Nz)    = 0;

    %% Quick Calculation Setup
    if quick_cal==1;
        Nmax    = Nx;
        Nx      = 100;
        Ny      = 100;
        Nz      = 100;
        Nx_low  = Nmax/2+1-Nx/2;
        Nz_low  = 1;
        Nx_high = Nmax/2+Nx/2;
        Nz_high = Nz;
        z       = z(Nz_low:Nz_high);
        y       = y(Nx_low:Nx_high);
        x       = x(Nx_low:Nx_high);
        Temp    = Temp(Nx_low:Nx_high,Nx_low:Nx_high,Nz_low:Nz_high);
        Ap      = Ap(Nx_low:Nx_high,Nx_low:Nx_high,Nz_low:Nz_high);
        T       = T(Nx_low:Nx_high,Nx_low:Nx_high,Nz_low:Nz_high);
        HC      = HC(Nx_low:Nx_high,Nx_low:Nx_high,Nz_low:Nz_high);
        TC      = TC(Nx_low:Nx_high,Nx_low:Nx_high,Nz_low:Nz_high);
    end

    %% Prepare the temperature plot
    figure(6)
    clf
    image(y,z,squeeze(Temp(:,Nx/2,:))')
    hold on
    text(max(x)*0.9,min(z)-0.04*max(z),'T [^{\circ}C]','fontsize',18)
    colorbar
    set(gca,'fontsize',18)
    xlabel('y [cm]')
    ylabel('z [cm]')
    title('Temperature [^{\circ}C] ')
    colormap(makec2f)
    axis equal image
    drawnow

    %% Heat Transfer Simulation during illumination
    if Apcal==1;
        fprintf(1,'Illuminating ...\n|----------------------------------------|');

        fprintf(1,'\b');
        tic
        for nt = 1:Nt_light
            % Calculates heat propagation
            dQ = zeros(size(Temp));

            heatTransfer = diff(Temp,1,1).*movmean(TC,2,1,'Endpoints','discard');
            dQ(1:Nx-1,:,:) = (dt/dx)*dy*dz*heatTransfer;
            dQ(2:Nx,:,:) = dQ(2:Nx,:,:)-(dt/dx)*dy*dz*heatTransfer;

            heatTransfer = diff(Temp,1,2).*movmean(TC,2,2,'Endpoints','discard');
            dQ(:,1:Nx-1,:) = dQ(:,1:Nx-1,:)+(dt/dy)*dx*dz*heatTransfer;
            dQ(:,2:Nx,:) = dQ(:,2:Nx,:)-(dt/dy)*dx*dz*heatTransfer;

            heatTransfer = diff(Temp,1,3).*movmean(TC,2,3,'Endpoints','discard');
            dQ(:,:,1:Nz-1) = dQ(:,:,1:Nz-1)+(dt/dz)*dx*dy*heatTransfer;
            dQ(:,:,2:Nz) = dQ(:,:,2:Nz)-(dt/dz)*dx*dy*heatTransfer;

            % sum of heat propagation and heat generated from absorbed light
            dQ = dQ+Ap*dx*dy*dz*Wdel*dt;
            % calculate the temperature at the next timestep
            Temp = Temp + dQ./HC./(dx*dy*dz);
            % plot the current temperature
            image(y,z,squeeze(Temp(:,Nx/2,:))')
            drawnow

            if mod(nt/Nt_light*40,1) == 0
                fprintf(1,'\b');
            end
        end
        fprintf(1,'\b\b Done\n');
        toc
    end

    Temp_post_light = Temp;
    Temp_post_light_zy = squeeze(Temp_post_light(:,Nx/2,:))';

    Temp_max = Temp;
    
    %% Plot the temperature distribution immediately after illumination

    figure(5);clf
    image(y,z,Temp_post_light_zy)
    hold on
    text(max(x)*0.9,min(z)-0.04*max(z),'T [^{\circ}C]','fontsize',18)
    colorbar
    set(gca,'fontsize',18)
    xlabel('y [cm]')
    ylabel('z [cm]')
    title('Temperature after Illumination [^{\circ}C] ')
    colormap(makec2f)
    axis equal image
    drawnow

    figure(6)

    %% Heat Transfer Simulation after illumination
    if postcal==1
        fprintf(1,'Diffusing ...\n|----------------------------------------|');

        fprintf(1,'\b');
        tic
        for nt = 1:Nt_no_light
            dQ = zeros(size(Temp));

            heatTransfer = diff(Temp,1,1).*movmean(TC,2,1,'Endpoints','discard');
            dQ(1:Nx-1,:,:) = (dt/dx)*dy*dz*heatTransfer;
            dQ(2:Nx,:,:) = dQ(2:Nx,:,:)-(dt/dx)*dy*dz*heatTransfer;

            heatTransfer = diff(Temp,1,2).*movmean(TC,2,2,'Endpoints','discard');
            dQ(:,1:Nx-1,:) = dQ(:,1:Nx-1,:)+(dt/dy)*dx*dz*heatTransfer;
            dQ(:,2:Nx,:) = dQ(:,2:Nx,:)-(dt/dy)*dx*dz*heatTransfer;

            heatTransfer = diff(Temp,1,3).*movmean(TC,2,3,'Endpoints','discard');
            dQ(:,:,1:Nz-1) = dQ(:,:,1:Nz-1)+(dt/dz)*dx*dy*heatTransfer;
            dQ(:,:,2:Nz) = dQ(:,:,2:Nz)-(dt/dz)*dx*dy*heatTransfer;

            % calculate the temperature at the next timestep
            Temp = Temp + dQ./HC./(dx*dy*dz);
            % save the maximum temperature that was ever reached at each point
            Temp_max = max(cat(4,Temp_max, Temp),[],4);
            % plot the current temperature
            image(y,z,squeeze(Temp(:,Nx/2,:))')
            drawnow

            if mod(nt/Nt_no_light*40,1) == 0
                fprintf(1,'\b');
            end
        end
        fprintf(1,'\b\b Done\n');
        toc
    end

    Temp_post_diffuse = Temp;
    Temp_post_diffuse_zy = squeeze(Temp_post_diffuse(:,Nx/2,:))';

    Temp_max_zy = squeeze(Temp_max(:,Nx/2,:))';

    %% Plot the temperature after diffusion and the maximum temperature reached

    figure(6);clf
    image(y,z,Temp_post_diffuse_zy)
    hold on
    text(max(x)*0.9,min(z)-0.04*max(z),'T [^{\circ}C]','fontsize',18)
    colorbar
    set(gca,'fontsize',18)
    xlabel('y [cm]')
    ylabel('z [cm]')
    title('Temperature after Diffusion [^{\circ}C]')
    colormap(makec2f)
    axis equal image

    figure(7);clf
    image(y,z,Temp_max_zy)
    hold on
    text(max(x)*0.9,min(z)-0.04*max(z),'T [^{\circ}C]','fontsize',18)
    colorbar
    set(gca,'fontsize',18)
    xlabel('y [cm]')
    ylabel('z [cm]')
    title('maximum Temperature reached [^{\circ}C]')
    colormap(makec2f)
    axis equal image

    %% Save the data for downstream processing (-> plotDead)
    if save_on==1
        save([directoryPath save_name],'Temp_post_light','Temp_post_diffuse','Temp_max','pulse_energy_area','pulse_duration','duration_after','Nx','Ny','Nz','Nt','dx','dy','dz','T',...
            'x','y','z','tissueList')
    end
end