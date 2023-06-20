function [oi, pupilMask, psf_spectral] = piFlareApply2(scene, varargin)
% Add lens flare to a scene/optical image.
%
% Synopsis:
%   [opticalImage, aperture]  = piFlareApply(scene, varargin)
%
% Brief description:
%   Apply a 'scattering flare' PSF to a scene and generate an optical
%   image. 
%
%   The scattering flare is implemented based on the paper "How to
%   Train Neural Networks for Flare Removal" by Wu et al.
%
% Inputs:
%   scene: An ISET scene structure.
%
% Optional Key/val pairs
%  num sides aperture
%  focal length
%  pixel size
%  max luminance
%  sensor size
%  dirty level
%
% Output:
%   opticalImage: An ISET optical image structure.
%   aperture:  Scratched aperture
%   psf_spectral - Spectral point spread function
%
% Description
%   The scattering flare is implemented as perturbations on the pupil
%   function (wavefront).  We have several ideas to implement to
%   extend the flare modeling
%
%      * Can we take in an OI and apply the flare to that?  How would
%      that work? Maybe we should compute the Pupil function from any
%      OI by estimating the point spread function and then deriving
%      the Pupil function (psf = abs(fft(pupil)).  We can't really
%      invert because of the abs, but maybe approximate?
%      * We should implement additional regular wavefront aberration
%      patterns, not just random scratches
%      * We should implement wavelength-dependent scratches. Now
%      the impact of the scratches is the same at all wavelengths
%      * Accept a geometric transform and apply that to if we start
%      with a scene.
%      
% See also
%   opticsDLCompute, opticsOTF (ISETCam)

% Examples:
%{


%}
%{
sceneSize = 512;
scene = sceneCreate('point array',sceneSize, 128);
scene = sceneSet(scene,'fov',1);
scene = sceneSet(scene, 'distance',0.05);
sceneSampleSize = sceneGet(scene,'sample size','m');
[oi,pupilmask, psf] = piFlareApply2(scene,...
                    'psf sample spacing', sceneSampleSize, ...
                    'numsidesaperture', 10, ...
                    'fnumber',5, 'dirtylevel',0);
oiWindow(oi);

ip = piOI2IP(oi,'etime',1/10);
ipWindow(ip);

% defocus
[oi,pupilmask, psf] = piFlareApply2(scene,...
                    'psf sample spacing', sceneSampleSize, ...
                    'numsidesaperture', 10, ...
                    'fnumber',5, 'dirtylevel',.5,...
                    'defocus term',2);
oiWindow(oi);

ip = piOI2IP(oi,'etime',1/10);
ipWindow(ip);
%}

%% Calculate the PSF using the complex pupil method.  
%
% The calculation enables creating a PSF with arbitrary wavefront
% aberrations. These are optical path differences (OPD) in the pupil.

%% Parse input
varargin = ieParamFormat(varargin);
p = inputParser;

p.addRequired('scene', @(x)isequal(class(x),'struct'));
p.addParameter('psfsamplespacing',0.25e-6); % PSF sample spacing (m)

% number of blades for aperture, 0 for circular aperture.
p.addParameter('numsidesaperture',0);
p.addParameter('focallength',4.5e-3); % Focal length (m)
p.addParameter('dirtylevel',0);       % Bigger number is more dirt.
% p.addParameter('normalizePSF',true);  % whether normalize the calculatedPSF
p.addParameter('fnumber', 5); % F-Number

% some parameters for defocus
p.addParameter('defocusterm', 0); % Zernike defocus term

p.addParameter('wavelist', 400:10:700, @isnumeric); % (nm)

p.parse(scene, varargin{:});

psfsamplespacing = p.Results.psfsamplespacing;

numSidesAperture = p.Results.numsidesaperture;
dirtylevel       = p.Results.dirtylevel;
focalLength      = p.Results.focallength;
fNumber          = p.Results.fnumber;

defocusTerm      = p.Results.defocusterm;
waveList         = p.Results.wavelist;

pupilDiameter   = focalLength / fNumber; % (m)

%% Starting with a scene, create an initial diffraction limited oi

% This code follows the logic in ISETCam routines 
%    opticsDLCompute and opticsOTF
% sz = sceneGet(scene,'size');
% sceneHeight = sz(1);
% sceneWidth  = sz(2);

oi = oiCreate('shift invariant');
oi = oiSet(oi,'optics focal length',focalLength);
oi = oiSet(oi,'optics f number',fNumber);
% optics = oiGet(oi,'optics');
% oi = oiSet(oi,'photons',oiCalculateIrradiance(scene,optics));
oi = oiCompute(oi,scene);

%{
% Apply some of the oi methods to the initialized oi data
offaxismethod = opticsGet(oi.optics,'off axis method');
switch lower(offaxismethod)
    case {'skip','none',''}
    case 'cos4th'
        oi = opticsCos4th(oi);
    otherwise
        fprintf('\n-----\nUnknown offaxis method: %s.\nUsing cos4th.',optics.offaxis);
        oi = opticsCos4th(oi);
end

% Pad the optical image to allow for light spread (code from isetcam)
padSize  = round([sceneHeight sceneWidth]/8);
padSize(3) = 0;
sDist = sceneGet(scene,'distance');
oi = oiPad(oi,padSize,sDist);

%}
oiSize = oiGet(oi,'size');

% oiHeight = oiSize(1); oiWidth = oiSize(2);

% oi = oiSet(oi, 'wAngular', 2*atand((oiWidth*psfsamplespacing/2)/focalLength));


%% Generate scratch and dirty markings in the aperture mask

% We might use the wavefront toolbox methods to create a PSF for the lens
% aperture with scratches.  We would start with a specification of the
% optics of the oi.  We then compute the PSF, using defocus, scratch level,
% and opacity parameters.  We then use the wvf to create an oi (wvf2oi) and
% compute from the scene (oiCompute).
%
% We would build the oi with a routine like this:
%  oi = oiCreate('shift invariant');  
%
%  % Set oi parameters
%  oi = oiSet(oi, ...)
%
%  % Compute the for the shift invariant oi
%  oi = oiFlare(oi,dirtylevel,opacity,defocus);
% 
% The oiFlare routine could be based on something like:
%
%     wvf = wvfCreate;
%     waveaberration = flare(pupil aperture, other parameters);
%     wvf = wvfSet(wvf,'image wavefront aberration',waveaberration);
%     wvf = wvfComputePSF(wvf);
%     oi = wvf2oi(wvf);
% 
% Then we would compute as usual for the shift invariant model
%
%  oi = oiCompute(oi,scene);
%

% Add the scratches/dirt
if dirtylevel>0
    %     if oiWidth>oiHeight
    %         imgSize = oiWidth;
    %     else
    %         imgSize = oiHeight;
    %     end

    % This serves as an amplitude mask applied to the pupil.  See the
    % calculation below of the pupilMask.
    imgSize = max(oiSize);
    dirtyAperture = apertureAmplitude(imgSize, dirtylevel);
    % ieNewGraphWin; imagesc(dirtyAperture); colormap(gray);
end

% We should add different methods to change the mask, beyond dirty.  They
% might go here.  The dirtyAperture might end up being a spectral function.

% For each wavelength, apply the dirty mask
nWave = numel(waveList);
oiHeight = oiSize(1); oiWidth = oiSize(2);
for ww = 1:nWave

    % Wavelength in meters
    wavelength = waveList(ww) * 1e-9; % (m)

    % Set up the pupil function
    pupilSampleStepX = 1 / (psfsamplespacing * oiWidth) * wavelength * focalLength;
    pupilSupportX = (-0.5: 1/oiWidth: 0.5-1/oiWidth) * pupilSampleStepX * oiWidth;    
    pupilSampleStepY = 1 / (psfsamplespacing * oiHeight) * wavelength * focalLength;
    pupilSupportY = (-0.5: 1/oiHeight: 0.5-1/oiHeight) * pupilSampleStepY * oiHeight;
    [pupilX, pupilY] = meshgrid(pupilSupportX, pupilSupportY);

    pupilRadius = 0.5*pupilDiameter;

    pupilRadialDistance = sqrt(pupilX.^2 + pupilY.^2);

    % Keep only the valid parts of the pupil, setting rother regions to
    % zero.
    pupilMask = (pupilRadialDistance <= pupilRadius);
    if numSidesAperture>0
        maskDiamter = find(pupilMask(oiHeight/2,:));
        centerPoint = [oiWidth/2+1,oiHeight/2+1];
        % create n-sided polygon
        pgon1 = nsidedpoly(numSidesAperture, 'Center', centerPoint, 'radius', floor(numel(maskDiamter)/2));
        % create a binary image with the polygon
        pgonmask = poly2mask(floor(pgon1.Vertices(:,1)), floor(pgon1.Vertices(:,2)), oiHeight, oiWidth);
        pupilMask = pupilMask.*pgonmask;
    end
    
    % Multiply the dirtyAperture by the pupilMask (which starts as all 1s)
    if dirtylevel>0
        pupilMask = pupilMask .* imresize(dirtyAperture,[oiHeight, oiWidth]);
    end

    % This is the normalized radial distance which will be used when we
    % evaluate the Zernike polynomials.  I think (BW).
    pupilRho = pupilRadialDistance./pupilRadius;

    % ----------------Comments From Google Flare Calculation---------------
    % Compute the Zernike polynomial of degree 2, order 0. Zernike
    % polynomials form a complete, orthogonal basis over the unit disk. The
    % "degree 2, order 0" component represents defocus, and is defined as
    % (in unnormalized form):
    %
    %     Z = 2 * r^2 - 1.
    %
    % Reference:
    % Paul Fricker (2021). Analyzing LASIK Optical Data Using Zernike Functions.
    % https://www.mathworks.com/company/newsletters/articles/analyzing-lasik-optical-data-using-zernike-functions.html
    % ---------------------------------------------------------------------

    % wavefrom is the wavefront aberration
    wavefront = zeros(size(pupilRho)) + defocusTerm*(2 * pupilRho .^2 - 1);

    % Pupil function combines the phase from the wavefront and amplitude
    % from the pupil mask
    phase_term = exp(1i*2 * pi .* wavefront);    
    OPD = phase_term.*pupilMask;
    % ieNewGraphWin; imagesc(wavefront);
    % ieNewGraphWin; imagesc(pupilMask);

    % Calculate the PSF from the pupil function
    % Compare this with wvfComputePupilFunction in the wvf tools
    psfFnAmp = fftshift(fft2(ifftshift(OPD)));
    inten = psfFnAmp .* conj(psfFnAmp);    % unnormalized PSF.
    shiftedPsf = real(inten);

    PSF = shiftedPsf./sum(shiftedPsf(:));
    PSF = PSF ./ sum(PSF(:));

    % Now we know the size of PSF.  Allocate space
    if ww == 1
        sz = size(PSF);
        psf_spectral = zeros(sz(1),sz(2),nWave);
        photons_fl   = zeros(sz(1),sz(2),nWave);
    end

    % In principle, we could calculate this wavelength dependent PSF,
    % attach it to the OI, and then perform oiCompute.
    psf_spectral(:,:,ww) = PSF;

    % Apply the psf to the photon data to create photons with flare.
    photons_fl(:,:,ww) = ImageConvFrequencyDomain(oi.data.photons(:,:,ww), psf_spectral(:,:,ww), 2 );

end

oi = oiSet(oi,'photons',photons_fl);
scene_size = sceneGet(scene,'size');
oi_size = oiGet(oi,'size');

% crop oi to remove extra edge
oi = oiCrop(oi, [(oi_size(2)-scene_size(2))/2,(oi_size(1)-scene_size(1))/2, ...
    scene_size(2)-1, scene_size(1)-1]);

% Compute illuminance, though not really necessary
oi = oiSet(oi,'illuminance',oiCalculateIlluminance(oi));

end

%% Below function is modified from google-flare code.
% https://github.com/google-research/google-research/tree/master/flare_removal

function im = apertureAmplitude(imagewidth, dirty_level)
% Synthetic dirty aperture with random dots and scratches.
%
% im = RandomDirtyAperture(mask)
%
% Returns an N x N monochromatic image emulating a dirty lens aperture.
%
% Specifically, we add disks and polylines of random size and opacity to an
% otherwise white image, in an attempt to model random dust and scratches. 
%
% TODO(qiurui): the spatial scale of the random dots and polylines are currently
%   hard-coded in order to match the paper. They should instead be relative
%   to the requested resolution, n.
%
% Arguments
%
% imagewidth: An [N, N]-logical matrix representing the aperture mask. Typically, this
%       should be a centered disk of 1 surrounded by 0.
%
% dirty_level: above or equal to 0.
% Returns
%
% im: An [N, N]-matrix of values in [0, 1] where 0 means completely opaque and 1
%     means completely transparent. The returned matrix is real-valued (i.e., we
%     ignore the phase shift that may be introduced by the "dust" and
%     "scratches").
%
% Required toolboxes: Computer Vision Toolbox.


n = imagewidth;
im = ones([n,n], 'single');

%% Add small dots (circles), simulating dust

% We might control the overall opacity as a means a defining how much flare
% we have in the image. (BW).
num_dots = max(0, round(20 + randn * 5));
num_dots = round(num_dots * dirty_level);
max_radius = max(0, 5 + randn * 50);
for i = 1:num_dots
  circle_xyr = rand(1, 3, 'single') .* [n, n, max_radius];
  opacity = 0.5 + rand * 0.5;
  im = insertShape(im, 'FilledCircle', circle_xyr, 'Color', 'black', ...
                  'Opacity', opacity);
end

%% Add polylines, simulating scratches

num_lines = max(0, round(20 + randn * 5));
num_lines = round(num_lines * dirty_level);
% max_width = max(0, round(5 + randn * 5));
for i = 1:num_lines
  num_segments = randi(16);
  start_xy = rand(2, 1) * n;
  segment_length = rand * 600;
  segments_xy = RandomPointsInUnitCircle(num_segments) * segment_length;
  vertices_xy = cumsum([start_xy, segments_xy], 2);
  vertices_xy = reshape(vertices_xy, 1, []);
  width = randi(5);

  % Note: the 'Opacity' option doesn't apply to lines, so we have to change the
  % line color to achieve a similar effect. Also note that [0.5 .. 1] opacity
  % maps to [0.5 .. 0] in color values.
  %
  % We could control the overall opacity here, as well.
  color = rand * 0.5;
  im = insertShape(im, 'Line', vertices_xy, 'LineWidth', width, ...
                   'Color', [color, color, color]);
end

% This serves as the phase mask.
im = rgb2gray(im);

% ieNewGraphWin; imagesc(im);

end

function xy = RandomPointsInUnitCircle(num_points)
r = rand(1, num_points, 'single');
theta = rand(1, num_points, 'single') * 2 * pi;
xy = [r .* cos(theta); r .* sin(theta)];
end