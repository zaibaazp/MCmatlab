addpath([fileparts(matlab.desktop.editor.getActiveFilename) '/helperfuncs']); % The helperfuncs folder is added to the path for the duration of this MATLAB session
fprintf('\n');

%% Description
% This example illustrates simulation of refraction and reflection
% according to Fresnel's equations. This requires the matchedInterfaces flag
% to be set to false. The geometry consists of three layers: At the bottom
% is a reflector such as metal (n = infinity), at the top is air (n = 1)
% and in between is water (n = 1.3). The light source is an isotropically
% emitting (equally emitting in all directions) source located inside the
% water layer. The rays can be seen to be reflected from the bottom
% interface and also to an extent from the top interface, although some
% light is also refracted out of the water.
%
% This example also shown the optional "useAllCPUs" flag that can be set on
% the MC simulations to slightly increase speed. Default is false, which
% means the solver leaves one CPU unused, making it easier to perform other
% work on the PC while simulations are running. Note that multithreading is
% anyway only supported on Windows. On Mac, useAllCPUs is ignored.
% 
% Additionally, the optional "nExamplePaths" parameter is demonstrated, a
% value specifying the number of photons whose paths should be stored and
% shown as lines in a 3D plot after completion.

%% Geometry definition
model = initializeMCmatlabModel();

model.G.nx                = 100; % Number of bins in the x direction
model.G.ny                = 100; % Number of bins in the y direction
model.G.nz                = 100; % Number of bins in the z direction
model.G.Lx                = .1; % [cm] x size of simulation cuboid
model.G.Ly                = .1; % [cm] y size of simulation cuboid
model.G.Lz                = .1; % [cm] z size of simulation cuboid

model.G.mediaPropertiesFunc = @mediaPropertiesFunc; % Media properties defined as a function at the end of this file
model.G.geomFunc          = @geometryDefinition_RefractionReflectionExample; % The distribution of media in the cuboid, also defined as a function at the end of this file.

% Execution, do not modify the next line:
model = defineGeometry(model);

plotMCmatlabGeom(model);

%% Monte Carlo simulation
model = clearMCmatlabModel(model,'MC'); % Only necessary if you want to run this section repeatedly, re-using previous G data

model.MC.useAllCPUs               = true; % If false, MCmatlab will leave one processor unused. Useful for doing other work on the PC while simulations are running.
model.MC.simulationTime           = .1; % [min] Time duration of the simulation
model.MC.nExamplePaths            = 100; % (Default: 0) This number of photons will have their paths stored and shown after completion, for illustrative purposes

model.MC.matchedInterfaces        = false; % If false, uses the refractive indices as defined in mediaPropertiesFunc at the end of this file
model.MC.boundaryType             = 1; % 0: No escaping boundaries, 1: All cuboid boundaries are escaping, 2: Top cuboid boundary only is escaping
model.MC.wavelength               = 532; % [nm] Excitation wavelength, used for determination of optical properties for excitation light

model.MC.beam.beamType            = 1; % 0: Pencil beam, 1: Isotropically emitting point source, 2: Infinite plane wave, 3: Gaussian focus, Gaussian far field beam, 4: Gaussian focus, top-hat far field beam, 5: Top-hat focus, Gaussian far field beam, 6: Top-hat focus, top-hat far field beam, 7: Laguerre-Gaussian LG01 beam
model.MC.beam.xFocus              = 0; % [cm] x position of focus
model.MC.beam.yFocus              = 0; % [cm] y position of focus
model.MC.beam.zFocus              = 0.04; % [cm] z position of focus
model.MC.beam.theta               = 0; % [rad] Polar angle of beam center axis
model.MC.beam.phi                 = 0; % [rad] Azimuthal angle of beam center axis
model.MC.beam.waist               = 0.005; % [cm] Beam waist 1/e^2 radius
model.MC.beam.divergence          = 5/180*pi; % [rad] Beam divergence 1/e^2 half-angle of beam (for a diffraction limited Gaussian beam, this is G.wavelength*1e-9/(pi*model.MC.beam.waist*1e-2))

% Execution, do not modify the next line:
model = runMonteCarlo(model);

plotMCmatlab(model);

%% Post-processing

%% Geometry function(s)
% A geometry function takes as input X,Y,Z matrices as returned by the
% "ndgrid" MATLAB function as well as any parameters the user may have
% provided in the definition of Ginput. It returns the media matrix M,
% containing numerical values indicating the media type (as defined in
% mediaPropertiesFunc) at each voxel location.
function M = geometryDefinition_RefractionReflectionExample(X,Y,Z,parameters)
M = ones(size(X)); % Air background
M(Z>0.03) = 2; % Water
M(Z>0.09) = 3; % Reflector
end

%% Media Properties function
% The media properties function defines all the optical and thermal
% properties of the media involved by constructing and returning a
% "mediaProperties" struct with various fields. As its input, the function
% takes the wavelength as well as any other parameters you might specify
% above in the model file, for example parameters that you might loop over
% in a for loop. Dependence on excitation fluence rate FR, temperature T or
% fractional heat damage FD can be specified as in examples 11-14.
function mediaProperties = mediaPropertiesFunc(wavelength,parameters)
j=1;
mediaProperties(j).name  = 'air';
mediaProperties(j).mua   = 1e-8;
mediaProperties(j).mus   = 1e-8;
mediaProperties(j).g     = 1;
mediaProperties(j).n     = 1;
mediaProperties(j).VHC   = 1.2e-3;
mediaProperties(j).TC    = 0; % Real value is 2.6e-4, but we set it to zero to neglect the heat transport to air

j=2;
mediaProperties(j).name  = 'water';
mediaProperties(j).mua   = 0.00036;
mediaProperties(j).mus   = 10;
mediaProperties(j).g     = 1.0;
mediaProperties(j).n     = 1.3;
mediaProperties(j).VHC   = 4.19;
mediaProperties(j).TC    = 5.8e-3;

j=3;
mediaProperties(j).name  = 'reflector';
mediaProperties(j).mua   = 1;
mediaProperties(j).mus   = 1;
mediaProperties(j).g     = 0;
mediaProperties(j).n     = Inf;
end