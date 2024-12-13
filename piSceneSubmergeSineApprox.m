function [submerged] = piSceneSubmergeSineApprox(thisR, medium, varargin)
p = inputParser;
p.addOptional('sizeX',1,@isnumeric);
p.addOptional('sizeY',1,@isnumeric);
p.addOptional('sizeZ',1,@isnumeric);
p.addOptional('offsetX',0, @isnumeric);
p.addOptional('offsetY',0, @isnumeric);
p.addOptional('offsetZ',0, @isnumeric);

p.parse(varargin{:});
inputs = p.Results;

%% Main Cube
submerged = copy(thisR);
submerged.set('integrator','volpath');

dx = inputs.sizeX/2;
dy = inputs.sizeY/2;
dz = inputs.sizeZ/2;

%Vertices of the cube
P = [ dx -dy  dz;
    dx -dy -dz;
    dx  dy -dz;
    dx  dy  dz;
    -dx -dy  dz;
    -dx -dy -dz;
    -dx  dy -dz;
    -dx  dy  dz;]';

indices = [4 0 3
    4 3 7
    0 1 2
    0 2 3
    1 5 6
    1 6 2
    5 4 7
    5 7 6
    7 3 2
    7 2 6
    0 5 1
    0 4 5]';

waterCubeMesh = piAssetCreate('type','trianglemesh');
waterCubeMesh.integerindices = indices(:)';
waterCubeMesh.point3p = P(:);

water = piAssetCreate('type','branch');
water.name = 'Water';
water.size.l = inputs.sizeX;
water.size.h = inputs.sizeY;
water.size.w = inputs.sizeZ;
water.size.pmin = [-dx; -dy; -dz];
water.size.pmax = [dx; dy; dz];
water.translation = {[inputs.offsetX; inputs.offsetY; inputs.offsetZ]};

waterID = piAssetAdd(submerged, 1, water);

waterMaterial = piMaterialCreate('WaterInterface','type','interface');

% This step loses the container maps
submerged.set('material','add',waterMaterial);

waterCube = piAssetCreate('type','object');
waterCube.name = 'WaterMesh';
waterCube.mediumInterface.inside = medium.name;
waterCube.mediumInterface.outside = [];
waterCube.material.namedmaterial = 'WaterInterface';
waterCube.shape = waterCubeMesh;

piAssetAdd(submerged, waterID, waterCube);
submerged.set('medium', 'add', medium);

%% Insert Rectangles
dx = 0.01 * inputs.sizeX/2; 
dy = 0.01 * inputs.sizeY/2; 
dzValues = [0.015, 0.025, 0.035, 0.045, 0.055, 0.055, 0.045, 0.035, 0.025, 0.015] * inputs.sizeZ/2;

for ix = -inputs.sizeX/2:2*dx:inputs.sizeX/2
    temp = 1;
    for iy = -inputs.sizeY/2:2*dy:inputs.sizeY/2
        dz = dzValues(temp);
        temp = temp + 1;
        temp = mod(temp + 1, length(dzValues));

        % Vertices of the rectangle
        P = [ dx -dy  dz;
              dx -dy -dz;
              dx  dy -dz;
              dx  dy  dz;
             -dx -dy  dz;
             -dx -dy -dz;
             -dx  dy -dz;
             -dx  dy  dz]';

        indices = [4 0 3;
                   4 3 7;
                   0 1 2;
                   0 2 3;
                   1 5 6;
                   1 6 2;
                   5 4 7;
                   5 7 6;
                   7 3 2;
                   7 2 6;
                   0 5 1;
                   0 4 5]';

        % Create the mesh
        waterCubeMesh = piAssetCreate('type', 'trianglemesh');
        waterCubeMesh.integerindices = indices(:)';
        waterCubeMesh.point3p = P(:);

        % Create the branch
        water = piAssetCreate('type', 'branch');
        water.name = 'Water';
        water.size.l = inputs.sizeX;
        water.size.h = inputs.sizeY;
        water.size.w = inputs.sizeZ;
        water.size.pmin = [-dx; -dy; -dz];
        water.size.pmax = [dx; dy; dz];
        %water.translation = {[ix + dx/2; iy + dy/2; inputs.sizeZ/2 + 0.43]};
        water.translation = {[ix + dx/2; iy + dy/2; inputs.sizeZ/2 + 0.3]};

        waterID = piAssetAdd(submerged, 1, water);

        % Create and add the material
        waterMaterial = piMaterialCreate('WaterInterface', 'type', 'interface');
        submerged.set('material', 'add', waterMaterial);

        % Add the mesh to the branch
        waterCube1 = piAssetCreate('type', 'object');
        waterCube1.name = 'WaterMesh';
        waterCube1.mediumInterface.inside = medium.name;
        waterCube1.mediumInterface.outside = [];
        waterCube1.material.namedmaterial = 'WaterInterface';
        waterCube1.shape = waterCubeMesh;

        piAssetAdd(submerged, waterID, waterCube1);
    end
end

    
%% Submerge the camera if needed
xstart = -dx + inputs.offsetX;
xend = dx + inputs.offsetX;

ystart = -dy + inputs.offsetY;
yend = dy + inputs.offsetY;

zstart = -dz + inputs.offsetZ;
zend = dz + inputs.offsetZ;

camPos = submerged.get('from');

if (xstart <= camPos(1) && camPos(1) <= xend) && ...
        (ystart <= camPos(2) && camPos(2) <= yend) && ...
        (zstart <= camPos(3) && camPos(3) <= zend)

    submerged.camera.medium = medium.name;

end

end