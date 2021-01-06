function ieObject = piDat2ISET(inputFile,varargin)
% Read a dat-file rendered by PBRT, and return an ieObject or a metadataMap
%
%    ieObject = piDat2ISET(inputFile,varargin)
%
% Brief description:
%    We take a dat-file from pbrt as input. We return an optical image.
%
% Inputs
%   inputFile -  Multi-spectral dat-file generated by pbrt.
%
% Optional key/value pairs
%   label            -  Specify the type of data: radiance, mesh, depth.
%                       Default is radiance
%   recipe           -  The recipe used to create the file
%   mean luminance   -  Set the mean illuminance
%   mean luminance per mm2 - Set the mean illuminance per square pupil mm
%   scalePupilArea -  if true, we scale the mean illuminance by the pupil
%                       diameter.
%
% Output
%   ieObject: if label is radiance: optical image;
%             else, a metadatMap
%
% Zhenyi/BW SCIEN Stanford, 2018
%
% See also
%   piReadDAT, oiCreate, oiSet

%% Examples
%{
 opticalImage = piDat2ISET('radiance.dat','label','radiance','recipe',thisR);
 meshImage    = piDat2ISET('mesh.dat','label','mesh');
 depthImage   = piDat2ISET('depth.dat','label','depth');
%}

%%
p = inputParser;
%varargin =ieParamFormat(varargin);
p.addRequired('inputFile',@(x)(exist(x,'file')));
p.addParameter('label','radiance',@(x)ischar(x));

p.addParameter('recipe',[],@(x)(isequal(class(x),'recipe')));
p.addParameter('wave', [], @isnumeric);

% For the OI case
p.addParameter('meanilluminancepermm2',5,@isnumeric);
p.addParameter('scalepupilarea',true,@islogical);

% For the pinhole case
p.addParameter('meanluminance',100,@isnumeric);

p.parse(inputFile,varargin{:});
label       = p.Results.label;
thisR       = p.Results.recipe;

meanIlluminancepermm2 = p.Results.meanilluminancepermm2;
scalePupilArea      = p.Results.scalepupilarea;
meanLuminance         = p.Results.meanluminance;
wave                  = p.Results.wave;

%% Depending on label, assign the output data properly to ieObject

% nWave = length(wave);
if(strcmp(label,'radiance') || strcmp(label, 'illuminant') || strcmp(label, 'illuminantonly'))
    
    % The PBRT output is in energy units.  Scenes and OIs data are
    % represented in photons
    energy = piReadDAT(inputFile);
    photons = Energy2Quanta(wave,energy);
    
    if strcmp(label, 'illuminant') || strcmp(label, 'illuminantonly')
        ieObject = photons;
        return;
    end
elseif(strcmp(label,'depth') || strcmp(label,'mesh')||strcmp(label,'material') )
    tmp = piReadDAT(inputFile);
    metadataMap = tmp(:,:,1); clear tmp;
    ieObject = metadataMap;
    return;
elseif(strcmp(label,'coordinates'))
    % Not sure what this is.  Maybe the 3D coordinates of each point?
    tmp = piReadDAT(inputFile);
    coordMap = tmp(:,:,1:3); clear tmp;
    ieObject = coordMap;
    return;
end

%% Read the data and set some of the ieObject parameters

% Only do the following if the recipe exists, otherwise just return the
% data
if(isempty(thisR))
    warning('Recipe not given. Returning photons directly.')
    ieObject = photons;
    return;
end

% Create a name for the ISET object
pbrtFile   = thisR.get('output basename');
ieObjName = sprintf('%s-%s',pbrtFile,datestr(now,'mmm-dd,HH:MM'));

% If radiance, return a scene or optical image
cameraType = thisR.get('camera subtype');
switch lower(cameraType)
    case {'realisticdiffraction','realistic','omni'}
        % If we used a lens, the ieObject is an optical image (irradiance).
        
        % We specify the mean illuminance of the OI mean illuminance
        % with respect to a 1 mm^2 aperture. That way, if we change
        % the aperture, but nothing else, the illuminance level will
        % scale correctly.

        % Try to find the optics parameters from the lensfile in the
        % PBRT recipe.  The function looks for metadata, if it cannot
        % find that slot it tries to decode the file name.  The file
        % name part should go away before too long because we can just
        % create the metadata once from the file name.
        [focalLength, fNumber] = piRecipeFindOpticsParams(thisR);
        
        % Start building the oi
        ieObject = piOICreate(photons,'wavelength',wave);
        
        % Set the parameters the best we can from the lens file.
        if ~isempty(focalLength)
            ieObject = oiSet(ieObject,'optics focal length',focalLength); 
        end
        if ~isempty(fNumber)
            ieObject = oiSet(ieObject,'optics fnumber',fNumber); 
        end
        
        % Calculate and set the oi 'fov' using the film diagonal size
        % and the lens information.  First get width of the film size.
        % This could be a function inside of get.
        filmDiag = thisR.get('film diagonal')*10^-3;  % In meters
        res      = thisR.get('film resolution');
        x        = res(1); y = res(2);
        d        = sqrt(x^2 + y^2);        % Number of samples along the diagonal
        filmwidth   = (filmDiag / d) * x;  % Diagonal size by d gives us mm per step
        
        % Next calculate the fov
        focalLength = oiGet(ieObject,'optics focal length');
        fov         = 2 * atan2d(filmwidth / 2, focalLength);
        ieObject    = oiSet(ieObject,'fov',fov);
        
        ieObject = oiSet(ieObject,'name',ieObjName);

        ieObject = oiSet(ieObject,'optics model','iset3d');
        if ~isempty(thisR)
            lensfile = thisR.get('lens file');
            ieObject = oiSet(ieObject,'optics name',lensfile);
        else
            warning('Render recipe is not specified.');
        end
        
        % We set meanIlluminance per square millimeter of the lens
        % aperture.
        if(scalePupilArea)
            aperture = oiGet(ieObject,'optics aperture diameter');
            lensArea = pi*(aperture*1e3/2)^2;
            meanIlluminance = meanIlluminancepermm2*lensArea;
            
            ieObject        = oiAdjustIlluminance(ieObject,meanIlluminance);
            ieObject.data.illuminance = oiCalculateIlluminance(ieObject);
        end
    case {'realisticeye'}
       % A human eye model, and the ieObject is an optical image (irradiance).
        
        focalLength = thisR.get('retina distance','m');
        pupilDiameter = thisR.get('pupil diameter','m');
        fNumber = focalLength/pupilDiameter;
        
        % Start building the oi
        ieObject = piOICreate(photons,'wavelength',wave);
        
        % Set the parameters the best we can from the lens file.
        ieObject = oiSet(ieObject,'optics focal length',focalLength);
        ieObject = oiSet(ieObject,'optics fnumber',fNumber);
        
        % Calculate and set the oi 'fov'.
        fov = thisR.get('fov');
        ieObject    = oiSet(ieObject,'fov',fov);
        
        ieObject = oiSet(ieObject,'name',ieObjName);

        ieObject = oiSet(ieObject,'optics model','iset3d');
        if ~isempty(thisR)
            eyeModel = thisR.get('realistic eye model');
            ieObject = oiSet(ieObject,'optics name',eyeModel);
        else
            % This should never happen!
            warning('Render recipe is not specified.');
        end
        
        % We set meanIlluminance per square millimeter of the lens
        % aperture.
        if(scalePupilArea)
            aperture = oiGet(ieObject,'optics aperture diameter');
            lensArea = pi*(aperture*1e3/2)^2;
            meanIlluminance = meanIlluminancepermm2*lensArea;
            
            ieObject        = oiAdjustIlluminance(ieObject,meanIlluminance);
            ieObject.data.illuminance = oiCalculateIlluminance(ieObject);
        end 
    case {'pinhole','environment','perspective'}
        % A scene radiance, not an oi
        ieObject = piSceneCreate(photons,...
                                    'wavelength', wave);
        ieObject = sceneSet(ieObject,'name',ieObjName);
        if ~isempty(thisR)
            % PBRT may have assigned a field of view
            ieObject = sceneSet(ieObject,'fov',thisR.get('fov'));
        end
        
        % In this case we cannot scale by the area because the aperture
        % is a pinhole.  The ieObject is a scene.  So we use the mean
        % luminance parameter (default is 100 cd/m2).
        ieObject = sceneAdjustLuminance(ieObject,meanLuminance);
        ieObject = sceneSet(ieObject,'luminance',sceneCalculateLuminance(ieObject));
    otherwise
        error('Unknown optics type %s\n',cameraType);       
end

end


