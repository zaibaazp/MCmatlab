addpath([fileparts(matlab.desktop.editor.getActiveFilename) '/helperfuncs']); % The helperfuncs folder is added to the path for the duration of this MATLAB session
fprintf('\n');

%% Description
% Here we show an example of how to model fluence rate dependent optical
% properties. We have a beam of light incident exactly on the interface
% between two saturable absorber materials. Material 1 has an absorption
% coefficient that reduces with fluence rate, while for material 2 both the
% absorption and scattering coefficients drop with fluence rate, and the
% scattering anisotropy increases with fluence rate, asymptotially up to 1.
% The formulas have been written in as char arrays in the media properties
% at the bottom of the file, using standard MATLAB syntax. In the formulas,
% FR is simply the normalized fluence rate times the power, FR =
% model.MC.NFR*model.MC.P.

% When simulating fluence rate or temperature dependent optical or thermal
% properties, the algorithm "bins" voxels of similar optical or thermal
% properties together. The number of bins used for fluence rate,
% temperature or damage fraction dependence is specified in the
% mediaProperties(j).nBins property of each of the relevant media. In other
% words, if nBins = 3, that medium will be split into "low fluence rate",
% "medium fluence rate" and "high fluence rate" sub-media with different
% (mua, mus, g) as far as the Monte Carlo algorithm is concerned. The total
% number of (sub-)media must not exceed 256. For illustration purposes, the
% number of bins used for saturable absorber 2 is intentionally set low (9)
% so that the binning becomes visible as discontinuities in the absorption
% plot.
% 
% The Monte Carlo simulation is run iteratively, using the previous run's
% fluence rate to determine the optical properties for the next run. The
% number of iterations is specified in model.MC.FRdepIterations, which is
% 20 by default. The specified simulation time or number of photons applies
% to the final iteration, while all the previous iterations will have
% shorter durations (scaling by a factor of 2 each time).
% 
% It is the user's responsibility to check that mediaProperties(j).nBins
% and model.MC.FRdepIterations are high enough for a suitably converged
% result.
% 
% In the result, you see that the collimated Gaussian beam narrows as it
% passes deeper in both of the saturable absorber media, which is because
% it is preferentially absorbed in the wings of the beam profile. The Media
% Properties figure show both the minimum and maximum achieved values of
% the optical properties for each of the saturable absorbers.

%% Geometry definition
model = initializeMCmatlabModel();

model.G.nx                  = 100; % Number of bins in the x direction
model.G.ny                  = 100; % Number of bins in the y direction
model.G.nz                  = 200; % Number of bins in the z direction
model.G.Lx                  = .1; % [cm] x size of simulation cuboid
model.G.Ly                  = .1; % [cm] y size of simulation cuboid
model.G.Lz                  = .2; % [cm] z size of simulation cuboid

model.G.mediaPropertiesFunc = @mediaPropertiesFunc; % Media properties defined as a function at the end of this file
model.G.geomFunc            = @geometryDefinition_SaturableAbsorber; % Function to use for defining the distribution of media in the cuboid. Defined at the end of this m file.

% Execution, do not modify the next line:
model = defineGeometry(model);

plotMCmatlabGeom(model);

%% Monte Carlo simulation
model = clearMCmatlabModel(model,'MC'); % Only necessary if you want to run this section repeatedly, re-using previous G data

model.MC.simulationTime           = .2; % [min] Time duration of the simulation

model.MC.matchedInterfaces        = true; % Assumes all refractive indices are 1
model.MC.boundaryType             = 1; % 0: No escaping boundaries, 1: All cuboid boundaries are escaping, 2: Top cuboid boundary only is escaping
model.MC.wavelength               = 532; % [nm] Excitation wavelength, used for determination of optical properties for excitation light

model.MC.beam.beamType            = 3; % 0: Pencil beam, 1: Isotropically emitting point source, 2: Infinite plane wave, 3: Gaussian focus, Gaussian far field beam, 4: Gaussian focus, top-hat far field beam, 5: Top-hat focus, Gaussian far field beam, 6: Top-hat focus, top-hat far field beam, 7: Laguerre-Gaussian LG01 beam
model.MC.beam.xFocus              = 0; % [cm] x position of focus
model.MC.beam.yFocus              = 0; % [cm] y position of focus
model.MC.beam.zFocus              = model.G.Lz/2; % [cm] z position of focus
model.MC.beam.theta               = 0; % [rad] Polar angle of beam center axis
model.MC.beam.phi                 = 0; % [rad] Azimuthal angle of beam center axis
model.MC.beam.waist               = 0.02; % [cm] Beam waist 1/e^2 radius
model.MC.beam.divergence          = 0; % [rad] Beam divergence 1/e^2 half-angle of beam (for a diffraction limited Gaussian beam, this is G.wavelength*1e-9/(pi*model.MC.beam.waist*1e-2))

model.MC.FRinitial = zeros(model.G.nx,model.G.ny,model.G.nz); % [W/cm^2] Initial guess for the intensity distribution, to be used for fluence rate dependent simulations
model.MC.P = 5; % [W] Power incident on top area of cuboid, used for calculations with fluence rate-dependent properties or for heat simulations
model.MC.FRdepIterations = 15;

% Execution, do not modify the next line:
model = runMonteCarlo(model); % Iteratively run Monte Carlo the default number of times (20) with simulation time (or nPhotons) increasing by a factor of 2 each time. Last run has simulation time equal to MC.simulationTime (or nPhotons equal to MC.nPhotonsRequested).

plotMCmatlab(model);

%% Post-processing

%% Geometry function(s)
% A geometry function takes as input X,Y,Z matrices as returned by the
% "ndgrid" MATLAB function as well as any parameters the user may have
% provided in the definition of Ginput. It returns the media matrix M,
% containing numerical values indicating the media type (as defined in
% mediaPropertiesFunc) at each voxel location.
function M = geometryDefinition_SaturableAbsorber(X,Y,Z,parameters)
absorberdepth = 0.03;
M = ones(size(X)); % Air
M(Z > absorberdepth) = 2; % Saturable absorber 1
M(Z > absorberdepth & Y > 0) = 3; % Saturable absorber 2
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
mediaProperties(j).name    = 'air';
mediaProperties(j).mua     = 1e-8;
mediaProperties(j).mus     = 1e-8;
mediaProperties(j).g       = 0;

j=2;
mediaProperties(j).name    = 'saturable absorber 1';
mediaProperties(j).mua     = '50./(1+FR/2000)';
mediaProperties(j).mus     = 10;
mediaProperties(j).g       = 0.9;
mediaProperties(j).nBins = 50; % Number of bins to use for the fluence rate- or temperature dependent (FRTDep) simulations. Higher is better and slower

j=3;
mediaProperties(j).name    = 'saturable absorber 2';
mediaProperties(j).mua     = '50./(1+FR/1000)';
mediaProperties(j).mus     = '10./(1+FR/500)';
mediaProperties(j).g       = '1-0.1./(1+FR/300)';
mediaProperties(j).nBins = 9; % Number of bins to use for the fluence rate- or temperature dependent (FRTDep) simulations. Higher is better and slower

end