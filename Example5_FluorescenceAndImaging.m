%% Description
% In this example, simulation of fluorescence (luminescence) is shown. The
% test geometry is a fluorescing cylinder in which excitation light is
% predominantly absorbed embedded in a block of medium in which
% fluorescence light is predominantly absorbed. The geometry is illuminated
% with an infinite plane wave.
%
% To illustrate the difference between specifying the fluorescence
% efficiency in terms of power yield (PY) or quantum yield (QY), the
% cylinder is composed of two different fluorescer materials, one with PY
% specified and one with QY specified. Note the difference in fluorescence
% of the two media.
%
% This example also shows detection of the light exiting the cuboid,
% separately for excitation light and for fluorescence light. Although most
% of the fluorescence light is absorbed in the medium surrounding the
% cylinder, some of it escapes to the detector, showing a slightly blurred
% image of the cylinder.
%
% To use a light collector, the cuboid boundary type towards the detector
% has to be set to "escaping". Additionally, the voxels touching that
% boundary must have a refractive index of 1.
%
% The "nExamplePaths" parameter (see example 3) is used for both the
% excitation and fluorescence simulations, showing paths of both kinds of
% photons.

%% Geometry definition
model = MCmatlab.model;

model.G.nx                = 100; % Number of bins in the x direction
model.G.ny                = 100; % Number of bins in the y direction
model.G.nz                = 100; % Number of bins in the z direction
model.G.Lx                = .1; % [cm] x size of simulation cuboid
model.G.Ly                = .1; % [cm] y size of simulation cuboid
model.G.Lz                = .1; % [cm] z size of simulation cuboid

model.G.mediaPropertiesFunc = @mediaPropertiesFunc; % Media properties defined as a function at the end of this file
model.G.geomFunc          = @geometryDefinition_FluorescingCylinder; % Function to use for defining the distribution of media in the cuboid. Defined at the end of this m file.

plot(model,'G');

%% Monte Carlo simulation
model.MC.useAllCPUs               = true; % If false, MCmatlab will leave one processor unused. Useful for doing other work on the PC while simulations are running.
model.MC.simulationTimeRequested  = .1; % [min] Time duration of the simulation
model.MC.nExamplePaths            = 100; % (Default: 0) This number of photons will have their paths stored and shown after completion, for illustrative purposes

model.MC.matchedInterfaces        = true; % Assumes all refractive indices are the same
model.MC.boundaryType             = 1; % 0: No escaping boundaries, 1: All cuboid boundaries are escaping, 2: Top cuboid boundary only is escaping
model.MC.wavelength               = 450; % [nm] Excitation wavelength, used for determination of optical properties for excitation light

model.MC.beam.beamType            = 2; % 0: Pencil beam, 1: Isotropically emitting line or point source, 2: Infinite plane wave, 3: Laguerre-Gaussian LG01 beam, 4: Radial-factorizable beam (e.g., a Gaussian beam), 5: X/Y factorizable beam (e.g., a rectangular LED emitter)
model.MC.beam.theta               = 0; % [rad] Polar angle of beam center axis
model.MC.beam.phi                 = 0; % [rad] Azimuthal angle of beam center axis

model.MC.useLightCollector        = true;

model.MC.LC.x                     = 0; % [cm] x position of either the center of the objective lens focal plane or the fiber tip
model.MC.LC.y                     = 0; % [cm] y position
model.MC.LC.z                     = 0.03; % [cm] z position

model.MC.LC.theta                 = 0; % [rad] Polar angle of direction the light collector is facing
model.MC.LC.phi                   = pi/2; % [rad] Azimuthal angle of direction the light collector is facing

model.MC.LC.f                     = .2; % [cm] Focal length of the objective lens (if light collector is a fiber, set this to Inf).
model.MC.LC.diam                  = .1; % [cm] Diameter of the light collector aperture. For an ideal thin lens, this is 2*f*tan(asin(NA)).
model.MC.LC.fieldSize             = .1; % [cm] Field Size of the imaging system (diameter of area in object plane that gets imaged). Only used for finite f.
model.MC.LC.NA                    = 0.22; % [-] Fiber NA. Only used for infinite f.

model.MC.LC.res                   = 50; % X and Y resolution of light collector in pixels, only used for finite f

% Execution, do not modify the next line:
model = runMonteCarlo(model);

plot(model,'MC');

%% Fluorescence Monte Carlo
model.FMC.useAllCPUs              = true; % If false, MCmatlab will leave one processor unused. Useful for doing other work on the PC while simulations are running.
model.FMC.simulationTimeRequested = .1; % [min] Time duration of the simulation
model.FMC.nExamplePaths           = 100; % (Default: 0) This number of photons will have their paths stored and shown after completion, for illustrative purposes

model.FMC.matchedInterfaces       = true; % Assumes all refractive indices are the same
model.FMC.boundaryType            = 1; % 0: No escaping boundaries, 1: All cuboid boundaries are escaping, 2: Top cuboid boundary only is escaping
model.FMC.wavelength              = 900; % [nm] Fluorescence wavelength, used for determination of optical properties for fluorescence light

model.FMC.useLightCollector       = true;

model.FMC.LC.x                    = 0; % [cm] x position of either the center of the objective lens focal plane or the fiber tip
model.FMC.LC.y                    = 0; % [cm] y position
model.FMC.LC.z                    = 0.03; % [cm] z position

model.FMC.LC.theta                = 0; % [rad] Polar angle of direction the light collector is facing
model.FMC.LC.phi                  = pi/2; % [rad] Azimuthal angle of direction the light collector is facing

model.FMC.LC.f                    = .2; % [cm] Focal length of the objective lens (if light collector is a fiber, set this to Inf).
model.FMC.LC.diam                 = .1; % [cm] Diameter of the light collector aperture. For an ideal thin lens, this is 2*f*tan(asin(NA)).
model.FMC.LC.fieldSize            = .1; % [cm] Field Size of the imaging system (diameter of area in object plane that gets imaged). Only used for finite f.
model.FMC.LC.NA                   = 0.22; % [-] Fiber NA. Only used for infinite f.

model.FMC.LC.res                  = 50; % X and Y resolution of light collector in pixels, only used for finite f

% Execution, do not modify the next line:
model = runMonteCarlo(model,'fluorescence');

plot(model,'FMC');

%% Geometry function(s)
% A geometry function takes as input X,Y,Z matrices as returned by the
% "ndgrid" MATLAB function as well as any parameters the user may have
% provided in the definition of Ginput. It returns the media matrix M,
% containing numerical values indicating the media type (as defined in
% mediaPropertiesFunc) at each voxel location.
function M = geometryDefinition_FluorescingCylinder(X,Y,Z,parameters)
    cylinderradius  = 0.0100;
    M = ones(size(X)); % fill background with fluorescence absorber
    M(Y.^2 + (Z - 3*cylinderradius).^2 < cylinderradius^2) = 2; % fluorescer
    M(Y.^2 + (Z - 3*cylinderradius).^2 < cylinderradius^2 & X > 0) = 3; % fluorescer
end

%% Media Properties function
% The media properties function defines all the optical and thermal
% properties of the media involved by constructing and returning a
% "mediaProperties" struct with various fields. As its input, the function
% takes the wavelength as well as any other parameters you might specify
% above in the model file, for example parameters that you might loop over
% in a for loop. Dependence on excitation fluence rate FR, temperature T or
% fractional heat damage FD can be specified as in examples 12-15.
function mediaProperties = mediaPropertiesFunc(wavelength,parameters)
    j=1;
    mediaProperties(j).name  = 'fluorescence absorber';
    if(wavelength<500)
        mediaProperties(j).mua = 1; % [cm^-1]
        mediaProperties(j).mus = 100; % [cm^-1]
        mediaProperties(j).g   = 0.9;
    else
        mediaProperties(j).mua = 100; % [cm^-1]
        mediaProperties(j).mus = 100; % [cm^-1]
        mediaProperties(j).g   = 0.9;
    end
    
    j=2;
    mediaProperties(j).name  = 'power yield fluorescer';
    if(wavelength<500)
        mediaProperties(j).mua = 100; % [cm^-1]
        mediaProperties(j).mus = 100; % [cm^-1]
        mediaProperties(j).g   = 0.9;
    else
        mediaProperties(j).mua = 1; % [cm^-1]
        mediaProperties(j).mus = 100; % [cm^-1]
        mediaProperties(j).g   = 0.9;
    end
    
    % Only one of PY and QY may be defined:
    mediaProperties(j).PY   = 0.4; % Fluorescence power yield (ratio of power emitted to power absorbed)
    % mediaProperties(j).QY   = 0.4; % Fluorescence quantum yield (ratio of photons emitted to photons absorbed)
    
    j=3;
    mediaProperties(j).name  = 'quantum yield fluorescer';
    if(wavelength<500)
        mediaProperties(j).mua = 100;
        mediaProperties(j).mus = 100;
        mediaProperties(j).g   = 0.9;
    else
        mediaProperties(j).mua = 1;
        mediaProperties(j).mus = 100;
        mediaProperties(j).g   = 0.9;
    end
    
    % Only one of PY and QY may be defined:
    % mediaProperties(j).PY   = 0.4; % Fluorescence power yield (ratio of power emitted to power absorbed)
    mediaProperties(j).QY   = 0.4; % Fluorescence quantum yield (ratio of photons emitted to photons absorbed)
end
