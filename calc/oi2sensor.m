function [outputFile] = oi2sensor(oiFiles, sensorFile)
%OI2SENSOR Accept an OI and sensor and output the sensor image
% D. Cardinal, B. Wandell, Zhenyi Liu, Stanford University, 2022

%
% oiFiles is (for now) the data file(s) for an Optical Image
% sensorFile is (for now) the data file for the desired sensor
%

% test for oiFiles as some type of array here

% These aren't actually optional yet:)
if isempty(oiFiles)
    oiFiles = 'sampleoi.mat';
end
if isempty(sensorFile)
    sensorFile = 'ar0132atSensorRGB.mat';
end

load(oiFiles);
sensor = sensorFromFile(sensorFile);

sensorImage = sensorCompute(sensor, oi);

outputFile = sensorSaveImage(sensorImage,"sensorRGB.png",'rgb');

end
