function heatSim()
%% User defined parameters

directoryPath = 'exec/';
myname = 'dentin_sim_850';
Wdel            = 1; % [W] Pulse peak power delivered
onduration      = 0.1; % [s] pulse on-duration
offduration     = 0.9; % [s] pulse off-duration
initialTemp     = 36; % [deg C]
plotTempLimits  = [36 36.15]; % [deg C], the expected range of temperatures, used only for setting the color scale in the plot

%% Load data
load([directoryPath myname '_HS.mat']);

%% Parameters that are set automatically

[nx,ny,nz] = size(T);
x  = ((0:nx-1)-(nx-1)/2)*dx;
y  = ((0:ny-1)-(ny-1)/2)*dy;
z  = ((0:nz-1)+1/2)*dz;

VHC = zeros(size(T));
TC = zeros(size(T));
for tissueNumber=1:length(tissueList)
    VHC(T==tissueNumber) = tissueList(tissueNumber).VHC;
    TC(T==tissueNumber) = tissueList(tissueNumber).TC;
end
HC = VHC*dx*dy*dz; % Heat capacity [J/K]

tissueIndicesInSimulation = unique(T);
[minVHC, minVHCindex] = min([tissueList(tissueIndicesInSimulation).VHC]);
[maxTC, maxTCindex] = max([tissueList(tissueIndicesInSimulation).TC]);
dtmax = min([dx dy dz])^2*minVHC/maxTC/10; % Max time step allowed
if onduration ~= 0
    nt_on = ceil(onduration/dtmax); % Number of time steps with illumination
    dt = onduration/nt_on; % Time step size
    nt_off = ceil(offduration/dt); % Number of time steps without illumination
else
    nt_on = 0;
    nt_off = ceil(offduration/dtmax); % Number of time steps with illumination
    dt = offduration/nt_off; % Time step size
end

fprintf('Illumination on for %d steps and off for %d steps. Step size is %0.2e s\n',nt_on,nt_off,dt);
fprintf('Step size is limited by VHC of %s (%0.1e J/(cm^3 K)) and TC of %s (%0.1e W/(cm K))\n',tissueList(tissueIndicesInSimulation(minVHCindex)).name,minVHC,tissueList(tissueIndicesInSimulation(maxTCindex)).name,maxTC);

Temp = initialTemp*ones(size(T));

%% Plots to visualize tissue properties

% figure(1);clf;
% plotVolumetric(x,y,z,T,tissueList);
% 
% figure(2);clf;
% plotVolumetric(x,y,z,VHC);
% 
% figure(3);clf;
% plotVolumetric(x,y,z,TC);

%% Prepare the temperature plot
h_f = figure(4);
plotVolumetric(x,y,z,Temp);
title('Temperature evolution');
caxis(plotTempLimits); % User-defined color scale limits
fprintf('Press (almost) any key to start simulation...\n')
pause

%% Heat Transfer Simulation during illumination
effectiveTCx = 2*TC(1:end-1,:,:).*TC(2:end,:,:)./(TC(1:end-1,:,:)+TC(2:end,:,:));
effectiveTCx(isnan(effectiveTCx)) = 0; % Neighboring insulating voxels would return NaN but should just be 0
effectiveTCy = 2*TC(:,1:end-1,:).*TC(:,2:end,:)./(TC(:,1:end-1,:)+TC(:,2:end,:));
effectiveTCy(isnan(effectiveTCy)) = 0;
effectiveTCz = 2*TC(:,:,1:end-1).*TC(:,:,2:end)./(TC(:,:,1:end-1)+TC(:,:,2:end));
effectiveTCz(isnan(effectiveTCz)) = 0;
dQperdeltaT_x = dt/dx*dy*dz*effectiveTCx;
dQperdeltaT_y = dt*dx/dy*dz*effectiveTCy;
dQperdeltaT_z = dt*dx*dy/dz*effectiveTCz;
dQ_abs = NVP*dt*dx*dy*dz*Wdel; % Heat from absorption per time step [J]
dQflowsx = zeros(size(Temp)+[1 0 0]);
dQflowsy = zeros(size(Temp)+[0 1 0]);
dQflowsz = zeros(size(Temp)+[0 0 1]);

tic
if nt_on
    fprintf(['Illuminating... \n' repmat('-',1,min(40,nt_on))]);
end
drawnow;
for i = 1:(nt_on + nt_off)
    if i == nt_on+1
        fprintf(['Diffusing heat... \n' repmat('-',1,min(40,nt_off))]);
    end
    dQflowsx(2:end-1,:,:) = diff(Temp,1,1).*dQperdeltaT_x;
    dQflowsy(:,2:end-1,:) = diff(Temp,1,2).*dQperdeltaT_y;
    dQflowsz(:,:,2:end-1) = diff(Temp,1,3).*dQperdeltaT_z;
    
    if i <= nt_on
        dQ  = diff(dQflowsx,1,1)...
            + diff(dQflowsy,1,2)...
            + diff(dQflowsz,1,3)...
            + dQ_abs;
    else
        dQ  = diff(dQflowsx,1,1)...
            + diff(dQflowsy,1,2)...
            + diff(dQflowsz,1,3);
    end    
    Temp = Temp + dQ./HC;

    if ismember(i,[floor(linspace(1,nt_on,40)) floor(linspace(nt_on + 1,nt_on + nt_off,40))])
        fprintf(1,'\b');
        updateVolumetric(h_f,Temp);
    end
    
    if i == nt_on
        Temp_illum = Temp;
        fprintf('\b\b Done\n');
    elseif i == nt_on + nt_off
        fprintf('\b\b Done\n');
    end
end
toc;

if ~nt_on
    title('Temperature after diffusion');
elseif ~nt_off
    title('Temperature after illumination');
else
    title('Temperature after diffusion')
    figure(5);
    plotVolumetric(x,y,z,Temp_illum);
    title('Temperature after illumination');
end
end

function [xr,yr,zr] = axisrotate(x,y,z,ux,uy,uz,theta)
st = sin(theta);
ct = cos(theta);

xr = (ct  +   ux*ux*(1-ct))*x	+	(ux*uy*(1-ct) - uz*st)*y	+	(ux*uz*(1-ct) + uy*st)*z;
yr = (uy*ux*(1-ct) + uz*st)*x	+	(ct  +   uy*uy*(1-ct))*y	+	(uy*uz*(1-ct) - ux*st)*z;
zr = (uz*ux*(1-ct) - uy*st)*x	+	(uz*uy*(1-ct) + ux*st)*y	+	(ct  +   uz*uz*(1-ct))*z;
end
