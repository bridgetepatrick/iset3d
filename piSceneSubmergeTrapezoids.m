function [submerged] = piSceneSubmergeTrapezoids(thisR, medium, varargin)
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

% Vertices of the cube
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

%% Insert Trapezoids
k = 0;

dx = 0.1*inputs.sizeX/2;
dy = inputs.sizeY/2;
dz = 0.1*inputs.sizeZ/2;

for i = 1:nearestDiv(inputs.sizeX,dx)/2
if (-inputs.sizeX/2 + k) > inputs.sizeX/2
    break
end

% Vertices of the trapezoid
P = [ (dx-0.25) -dy  dz;
      dx -dy -dz;
      dx  dy -dz;
      (dx-0.25)  dy  dz;
     -(dx-0.25) -dy  dz;
     -dx -dy -dz;
     -dx  dy -dz;
     -(dx-0.25)  dy  dz]';

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
water.translation = {[-inputs.sizeX/2 + dx + k; inputs.offsetY; inputs.sizeZ/2 + 0.43]};

waterID = piAssetAdd(submerged, 1, water);

waterMaterial = piMaterialCreate('WaterInterface','type','interface');

% This step loses the container maps
submerged.set('material','add',waterMaterial);

waterCube1 = piAssetCreate('type','object');
waterCube1.name = 'WaterMesh';
waterCube1.mediumInterface.inside = medium.name;
waterCube1.mediumInterface.outside = [];
waterCube1.material.namedmaterial = 'WaterInterface';
waterCube1.shape = waterCubeMesh;

piAssetAdd(submerged, waterID, waterCube1);
submerged.set('medium', 'add', medium);

k = k+3*dx;
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