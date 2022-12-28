% Might become a way to render specific characters on a background
% in preparation to reconstruction and scoring
%
% D. Cardinal Stanford University, 2022
%

%% clear the decks
ieInit;
if ~piDockerExists, piDockerConfig; end

% Something still isn't quite right about the H and I assets
% Small d also appears broken
Alphabet_UC = 'ABCDEFGJKLMNOPQRSTUVWXYZ';
Alphabet_LC = 'abcefghijklmnopqrstuvwxyz';
Digits = '0123456789';
allCharacters = [Alphabet_LC Alphabet_UC Digits];

testChars = 'D'; % just a few for debugging

humanEye = ~piCamBio(); % if using ISETBio, then use human eye

% Start with a "generic" recipe
[thisR, ourMaterials, ourBackground] = prepRecipe('flashCards');

% now we want to make the scene FOV 1 degree
% I think we need a camera first
thisR.camera = piCameraCreate('pinhole');
thisR.recipeSet('fov', 50/60); % 50 arc-minutes is enough for 200/20

% NOTE: We may not allow for any "padding" that is in the character
%       assets, around the edges of the actual character.

% Set quality parameters
% High-fidelity
thisR.set('rays per pixel',1024);
% Normal-fidelity
thisR.set('rays per pixel',128);

% set our film to a square
filmSideLength = 240;
recipeSet(thisR, 'film resolution', [filmSideLength filmSideLength]);

% We've set our scene to be 1 degree (60 arc-minutes) @ 6 meters
% For 20/20 vision characters should be .00873 meters high (5 arc-minutes)
% For 200/20 they are 50 arc-minutes (or .0873 meters high)
% EXCEPT our Assets include blank backgrounds (Sigh)
% Note that letter size is per our Blender assets which are l w h,
% NOT x, y, z
charMultiple = 10; % how many times the 20/20 version
charBaseline = .00873;
charSize = charMultiple * charBaseline;

% and lower the character position by half its size
%{
% for testing
charactersRender(thisR,testChars,'letterSize',[charSize .02 charSize], ...
    letterPosition=[0 -1*(charSize/2) 6]); % 6 Meters out
%}
% Now generate a full set of flash cards with black
numMat = 0;

% Can run one of the three, but maybe not all at once?
%useCharset = Digits; % Works
%useCharset = Alphabet_UC; % Works
useCharset = Alphabet_LC; % Works
for ii = 1:numel(useCharset)

    % also need to set material for letter
    numMat = numMat+ 1;
    useMat = ourMaterials(mod(numMat, numel(ourMaterials)));

    charactersRender(thisR,useCharset(ii), 'letterSize',[charSize .02 charSize], ...
        'letterPosition',[0 -1*(charSize/2), 6], ...
        'letterMaterial', useMat{1}.name);
end

% obj is either a scene, or an oi if we use optics
[obj] = piWRS(thisR);

DoEyeStuff(obj); % figure out what we want here

%% ------------- Support Functions Start Here
%%

function addMaterials(thisR)

% See list of materials, if we want to select some
allMaterials = piMaterialPresets('list', [],'show',false);

% Loop through our material list, adding whichever ones work
for iii = 1:numel(allMaterials)
    try
        piMaterialsInsert(thisR, 'names',allMaterials{iii});
    catch
        warning('Material: %s insert failed. \n',allMaterials{ii});
    end
end
end

function [thisR, ourMaterials, ourBackground] = prepRecipe(sceneName)

thisR = piRecipeDefault('scene name',sceneName);
thisR = addLight(thisR);

% Give it a skylight (assumes we want one)
thisR.set('skymap','sky-sunlight.exr');

addMaterials(thisR);
ourMaterialsMap = thisR.get('materials');
ourMaterials = values(ourMaterialsMap);

recipeSet(thisR,'to',[0 .01 10]);

% set vertical to 0. -6 gives us 6m or 20 feet
recipeSet(thisR,'from',[0 .01 -6]);

% Now set the place/color of the background
ourBackground = piAssetSearch(thisR,'object name', 'flashCard_O');
% background is at 0 0 0 by default
piAssetTranslate(thisR,ourBackground,[0 .01 10]); % just behind center

end


function thisR = addLight(thisR)
spectrumScale = 1;
lightSpectrum = 'equalEnergy';
lgt = piLightCreate('scene light',...
    'type', 'distant',...
    'specscale float', spectrumScale,...
    'spd spectrum', lightSpectrum,...
    'from', [0 0 0],  'to', [0 0 20]);
thisR.set('light', lgt, 'add');

end

%% Eye/Cone code grafted from s_eyeChart
%% Need to simplify & customize

function DoEyeStuff(obj, options) % TBD

arguments
    obj;
    options.thisName = 'letter';
end

% not sure if we can compare class or not
if isequal(class(obj),'oi')
    error("Don't know how to handle oi");
else
    scene = obj;
end

%  Needs ISETBio -- set thread pool for performance
if piCamBio
    warning('Cone Mosaic requires ISETBio');
    return
else

    poolobj = gcp('nocreate');
    if isempty(poolobj)
        parpool('Threads');
    end

    % we can render the cone mosaics, but another option is an eye model
    useConeMosaic = true;

    if useConeMosaic
        % Create the coneMosaic object
        % We want this to be about .35mm in diameter
        % or 1 degree FOV
        cMosaic = coneMosaic;
        cMosaic.fov = [1 1]; % 1 degree in each dimension
        cMosaic.emGenSequence(50);
        oi = oiCreate('wvf human');

        oi = oiCompute(oi, scene);
        cMosaic.name = options.thisName;
        cMosaic.compute(oi);
        cMosaic.computeCurrent;

        cMosaic.window;

    else % Try Arizona eye model

        thisSE = thisR;

        % humaneye is part of the latest CPU docker images
        % but is not currently supported on the GPU
        thisDWrapper = dockerWrapper;
        thisDWrapper.remoteCPUImage = 'digitalprodev/pbrt-v4-cpu';
        thisDWrapper.gpuRendering = 0;

        thisSE.recipe.set('render type', {'radiance','depth'});

        %%  Render

        scene = thisSE.render('docker wrapper',thisDWrapper);

        sceneWindow(scene);

        thisSE.summary;

        %% Now use the optics model with chromatic aberration

        % Turn off the pinhole.  The model eye (by default) is the Navarro model.
        thisSE.set('use optics',true);

        % True by default anyway
        thisSE.set('mmUnits', false);

        % We turn on chromatic aberration.  That slows down the calculation, but
        % makes it more accurate and interesting.  We often use only 8 spectral
        % bands for speed and to get a rought sense. You can use up to 31.  It is
        % slow, but that's what we do here because we are only rendering once. When
        % the GPU work is completed, this will be fast!

        % Distance in meters to objects to govern accommodation.
        %thisSE.set('to',toA); distA = thisSE.get('object distance');
        %thisSE.set('to',toB); distB = thisSE.get('object distance');
        %thisSE.set('to',toC); distC = thisSE.get('object distance');
        %thisSE.set('to',toB);

        % This is the distance we set our accommodation to that. Try distC + 0.5
        % and then distA.  At a resolution of 512, I can see the difference.  I
        % don't really understand the units here, though.  (BW).
        %
        % thisSE.set('accommodation',1/(distC + 0.5));

        %thisSE.set('object distance',distC);

        % We can reduce the rendering noise by using more rays. This takes a while.
        thisSE.set('rays per pixel',256);

        % Increase the spatial resolution by adding more spatial samples.
        thisSE.set('spatial samples',256);

        % Ray bounces
        thisSE.set('n bounces',3);

        %% Have a at the letters. Lots of things you can plot in this window.

        dockerWrapper.reset();
        thisDWrapper = dockerWrapper;
        thisDWrapper.remoteCPUImage = 'digitalprodev/pbrt-v4-cpu';
        thisDWrapper.gpuRendering = 0;
        thisSE.recipe.set('render type', {'radiance','depth'});

        % Runs on the CPU on mux for humaneye case.
        oi = thisSE.render('docker wrapper',thisDWrapper);

        oiWindow(oi);

        % Summarize
        thisSE.summary;
    end
end
end