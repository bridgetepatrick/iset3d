function [newMat, presetList] = piMaterialPresets(keyword,materialName)
% Create a material from some pretuned  cases
%
% Syntax:
%    [newMat, materialpresetsList] = piMaterialPresets(keyword,materialName)
%
% Brief description
%    Return material (some with textures) with keyword.
%
% Inputs:
%    keyword      - Material preset name or the special string
%                   'preview'
%    materialName - Material name which is used to create new material.
%
% Outputs:
%    newMat      - Material and a list of textures if used.
%    pressetList - Avaliable material presets.
%
% Zhenyi, 2022
%
% See also
%   piMaterialsInsert
%

%Examples:
%{
    piMaterialPresets('list material');
    piMaterialPresets('preview','fabric-leather-var1.jpg');
    piMaterialPresets('preview','rough-metal');
    piMaterialPresets('preview','metal-Ag');  % Mirror

%}
%{
    new_material = piMaterialPresets('glass','glassDemo');
%}
%{
  newMat = piMaterialPresets('wood-floor-merbau','woodfloor');
%}
%{
  newMat = piMaterialPresets('tiles-marble-sagegreen-brick','GreenMarble');
%}
%% Parameters
keyword = ieParamFormat(keyword);

% These are the materials we have preset.
presetList ={'glass','glass-BK7','glass-BAF10','glass-LASF9','glass-F5','glass-F10','glass-F11'...
    'metal-Ag','metal-Al','metal-Au','metal-Cu','metal-CuZn','metal-MgO','metal-TiO2',...
    'red-glass', 'tire','rough-metal','metal-spotty-discoloration','wood-floor-merbau',...
    'fabric-leather-var1','fabric-leather-var2','fabric-leather-var3','tiles-marble-sagegreen-brick'};

% Make sure this is directory on your path, though honestly, I am not
% sure why it wouldn't always be (BW).
materialPath = fullfile(piRootPath,'data/materials');
addpath(genpath(materialPath));

%% Depending on the key word, go for it.
switch keyword
    case 'preview'
        % The user wants to see a preview of a material.  Not all
        % materials have a preview.

        % piMaterialPresets('preview','glass-F11');
        if exist('materialName','var') && ~isempty(materialName)
            [~,n,e] = fileparts(materialName);
            if isempty(e), materialName = [n,'.jpg']; end

            fname = fullfile(materialPath,'previews',materialName);
            if exist(fullfile(materialPath,'previews',materialName), 'file')
                ieNewGraphWin; im = imread(fname); image(im);
            else
                warning('Could not find %s. Here are the files',materialName);
                dir(fullfile(materialPath,'previews'))
            end
        else
            dir(fullfile(materialPath,'previews'))
        end
        return;

        % The user wants a list of all the materials.
    case {'listmaterial','listmaterials'}
        % do nothing
        newMat = [];
        fprintf('\n---Names of preset materials ---\n');

        for ii = 1:numel(presetList)
            fprintf('%d: %s \n',ii, presetList{ii});
        end
        fprintf('---------------------\n');


        % GLASS
    case 'glass'
        newMat.material = piMaterialCreate(materialName,'type',...
            'dielectric','roughness',0);

    case 'red-glass'
        newMat_glass = piMaterialCreate([materialName, '_mix_glass'], ...
            'type', 'dielectric','eta','glass-BK7');
        newMat_reflectance = piMaterialCreate([materialName, '_mix_reflectance'], ...
            'type', 'coateddiffuse',...
            'reflectance', [ 0.99 0.01 0.01 ], ...
            'roughness',0);
        mixMatString{1} = [materialName, '_mix_glass'];
        mixMatString{2} = [materialName, '_mix_reflectance'];
        newMat.material = piMaterialCreate(materialName,...
            'type','mix',...
            'amount',0.2,...
            'materials',mixMatString);

        newMat.mixMat{1} = newMat_glass;
        newMat.mixMat{2} = newMat_reflectance;

    case 'glass-bk7'
        newMat.material = piMaterialCreate(materialName,...
            'type','dielectric',...
            'roughness',0,'eta','glass-BK7');

    case 'glass-baf10'
        newMat.material = piMaterialCreate(materialName,...
            'type','dielectric',...
            'roughness',0,'eta','glass-BAF10');

    case 'glass-fk51a'
        newMat.material = piMaterialCreate(materialName,...
            'type','dielectric',...
            'roughness',0,'eta','glass-FK51A');

    case 'glass-lasf9'
        newMat.material = piMaterialCreate(materialName,...
            'type','dielectric',...
            'roughness',0,'eta','glass-LASF9');

    case 'glass-f5'
        newMat.material = piMaterialCreate(materialName,...
            'type','dielectric',...
            'roughness',0,'eta','glass-F5');

    case 'glass-f10'
        newMat.material = piMaterialCreate(materialName,...
            'type','dielectric',...
            'roughness',0,'eta','glass-F10');

    case 'glass-f11'
        newMat.material = piMaterialCreate(materialName,...
            'type','dielectric',...
            'roughness',0,'eta','glass-F11');

        % METALS
    case 'metal-ag'
        newMat.material = piMaterialCreate(materialName, ...
            'type', 'conductor','eta','metal-Ag-eta','k','metal-Ag-k');

    case {'metal-al','rim', 'chrome'}
        newMat.material = piMaterialCreate(materialName, ...
            'type', 'conductor','eta','metal-Al-eta','k','metal-Al-k');

    case 'metal-au'
        newMat.material = piMaterialCreate(materialName, ...
            'type', 'conductor','eta','metal-Au-eta','k','metal-Au-k');

    case 'metal-cu'
        newMat.material = piMaterialCreate(materialName, ...
            'type', 'conductor','eta','metal-Cu-eta','k','metal-Cu-k');
    case 'metal-cuzn'
        newMat.material = piMaterialCreate(materialName, ...
            'type', 'conductor','eta','metal-CuZn-eta','k','metal-CuZn-k');
    case 'metal-mgo'
        newMat.material = piMaterialCreate(materialName, ...
            'type', 'conductor','eta','metal-MgO-eta','k','metal-MgO-k');
    case 'metal-tio2'
        newMat.material = piMaterialCreate(materialName, ...
            'type', 'conductor','eta','metal-TiO2-eta','k','metal-TiO2-k');
    case 'rough-metal'
        newMat.material = piMaterialCreate(materialName, ...
            'type', 'conductor','eta','metal-Al-eta','k','metal-Al-k',...
            'uroughness',0.05,'vroughness',0.05);

        % These materials are from the polligon website
        % https://www.poliigon.com/textures/free
    case 'metal-spotty-discoloration'
        newMat = polligon_materialCreate(materialName,...
            'MetalSpottyDiscoloration001_COL_3K_METALNESS.png','coatedconductor');

        % Car materials
    case 'tire'
        newMat.material = piMaterialCreate(materialName, ...
            'type', 'coateddiffuse','reflectance',[ 0.06394 0.06235 0.06235 ],'roughness',0.1);

        % Woods
    case 'wood-floor-merbau'
        newMat = polligon_materialCreate(materialName,...
            'WoodFlooringMerbauBrickBondNatural001_COL_3K.png','coateddiffuse');

        % Fabrics
    case 'fabric-leather-var1'
        newMat = polligon_materialCreate(materialName,...
            'FabricLeatherBuffaloRustic001_COL_VAR1_3K.png','coateddiffuse');

    case 'fabric-leather-var2'
        newMat = polligon_materialCreate(materialName,...
            'FabricLeatherBuffaloRustic001_COL_VAR2_3K.png','coateddiffuse');

    case 'fabric-leather-var3'
        newMat = polligon_materialCreate(materialName,...
            'FabricLeatherBuffaloRustic001_COL_VAR3_3K.png','coateddiffuse');

    otherwise
        warning('No material preset found for %s',keyword);
        piMaterialPresets('list material');
end

end

function newMat = polligon_materialCreate(materialName, material_ref, materialType)
% We sometimes download textures from this web-site
%
% Polligon website: https://www.poliigon.com/textures/free
%
% When we do, they have a number of files that we assign to the
% variables of the material in this function.
%
% material_ref is diffuse color texture in the folder which user
% directly unzipped from the zip file downloaded from polligon website.

%%
texfile = which(material_ref);   % Texture file
if isempty(texfile)
    % We should probably go to ieWebGet() for the texture.  See
    % example just below here.
    error('File is not found! Make sure the file exists!');

    % This is one I downloaded and we should figure out how to put
    % these up on the web server and download.
    %
    %    case 'tiles-marble-sagegreen-brick'
    %    newMat = polligon_materialCreate(materialName,...
    %    'TilesMarbleSageGreenBrickBondHoned001_COL_2K.jpg','coateddiffuse');
end

[texdir] = fileparts(texfile);

filelists = dir(texdir);

tex_ref    = piTextureCreate([materialName,'_tex_ref'],...
    'type','imagemap',...
    'filename',material_ref);
newMat.texture{1} = tex_ref;
normal_texture = [];
tex_displacement = [];
tex_roughness = [];
for ii = 1:numel(filelists)
    if contains(filelists(ii).name, 'NRM')
        normal_texture = filelists(ii).name;
    end

    if contains(filelists(ii).name, 'DISP16')
        displacement_texture = filelists(ii).name;

        tex_displacement = piTextureCreate([materialName,'_tex_displacement'],...
            'type','imagemap',...
            'format','float',...
            'filename',displacement_texture);
        newMat.texture{end+1} = tex_displacement;
    end

    if contains(filelists(ii).name, {'REFL','ROUGHNESS'})
        roughness_texture = filelists(ii).name;

        tex_roughness = piTextureCreate([materialName,'_tex_roughness'],...
            'type','imagemap',...
            'format','float',...
            'filename',roughness_texture);
        newMat.texture{end+1} = tex_roughness;
    end
end

% Parameters based on the material type
switch materialType
    case 'coateddiffuse'
        material = piMaterialCreate(materialName,...
            'type','coateddiffuse',...
            'reflectance',[materialName,'_tex_ref']);

        if ~isempty(normal_texture)
            material = piMaterialSet(material,'normalmap',normal_texture);
            % material.normalmap.value = normal_texture;
        end
        if ~isempty(tex_roughness)
            material = piMaterialSet(material,'roughness',[materialName,'_tex_roughness']);
            % material.roughness.value = [materialName,'_tex_roughness'];
        end
        if ~isempty(tex_displacement)
            material = piMaterialSet(material,'displacement',[materialName,'_tex_displacement']);
            % material.displacement.value = [materialName,'_tex_displacement'];
        end

    case 'coatedconductor'
        material = piMaterialCreate(materialName,...
            'type','coatedconductor',...
            'reflectance',[materialName,'_tex_ref'],...
            'interfaceroughness',0.01);

        if ~isempty(normal_texture')
            material = piMaterialSet(material,'normalmap',normal_texture);
            % material.normalmap.value = normal_texture;
        end
        if ~isempty(tex_roughness)
            material = piMaterialSet(material,'conductorroughness',[materialName,'_tex_roughness']);
            % material.conductorroughness.type  = 'texture';
            % material.conductorroughness.value = [materialName,'_tex_roughness'];
        end

        if ~isempty(tex_displacement)
            material = piMaterialSet(material,'displacement',[materialName,'_tex_displacement']);
            % material.displacement.value = [materialName,'_tex_displacement'];
        end
end

newMat.material = material;

end



