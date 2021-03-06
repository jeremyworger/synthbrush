%TODO, recompile GraphicsMagick to get more bits per pixel in images
% see http://wiki.octave.org/GraphicsMagick
%AND THEN, rebuild octave (a.k.a major pain in the bum)
%TODO make the blue channel work.
   %  Suggestion: make one function working for grayscale
   %  And then call this SAME function once for each channel
   % avoids repetition


function[]=synthbrush(inputImage)

%--------- Local Parameters -------------------------
%inputImage = 'fromInkscape2.png';
outputWav = horzcat(inputImage,'.wav');
%----------------------------------------------------
logEnvelope = 1; %operates in dB
verbose=0; %plots envelopes for all non-zero lines

parameters; %set up the parameters (see parameters.m)

%Read the input image
inIm = imread(inputImage);

%Crop zeroed striped from start and end
%this allows comment area before and after,
%without affecting the sound
%sound only goes from first nonZero column until the
%last non zero column
sumImageR = sum(inIm(:,:,1));
nonZero = find(sumImageR>0);
inIm2(:,:,1) = inIm(:,nonZero(1):nonZero(end),1);
inIm2(:,:,2) = inIm(:,nonZero(1):nonZero(end),2);
inIm2(:,:,3) = inIm(:,nonZero(1):nonZero(end),3);
inIm = inIm2; clear inIm2; %WOP

%derive stuff from image
octaveSpan = size(inIm,1)/freqRes;
%limited to whole octave files
%TODO flexibilize this:
% boils down to rethink the freqVector generation
if mod(octaveSpan,1)~=0
   error('Image must have whole octaves');
end

duration = (size(inIm,2)-1)/imageColumnPerSecond; %seconds

freqVector = minFreq ...
             *2.^(transpose(fliplr([0:1/freqRes:octaveSpan]))); %Hz
freqVector = 2*pi*freqVector; %rad/s

%time line
timeVector = [1/fs:1/fs:duration]; %seconds, really long vector
Rout = zeros(size(timeVector));
%upsampling factor
upsamplingFactor = fs/imageColumnPerSecond; %Samples per ImageColumn
%TODO flexibilize this, boils down to making a proper upsample algorithm
%(i.e. one that can upsample by non integer factors)
if mod(upsamplingFactor,1)~=0
   error('Fs must be a multiple of image column per second');
end


%%lazy algorithm (a.k.a I skiped my DSP classes and forgot how to window an FFT)
%%complexity O(n*m) n time; m freq
%for each line of the image
  % upsample the line from image time resolution to sound time resolution
  %interpolate the upsampled line, thus getting an envelope
  % multiply the envelope with the corresponding sinewave
      %tip: randomize the inital phase of each frequency to avoid the dirac
  % acumulate the result in the final audio vector
%end for
for m=[1:1:length(freqVector)-1]%WOP -1
 imageLine = double(inIm(m,:,1));%WOP, only getting the right channel!!!
 if(sum(imageLine(:))>0) %only process lines with content
  envelope = real(interp1(imageLine,[1:1/upsamplingFactor:length(imageLine)]));
  envelope = envelope(2:end);
  %make a sine vector the same size of the time vector
  %at frequency m
  %with a random initial phase (to spread the noise energy along time) 
  sineVector = sin(2*pi*rand+ ... %random phase
                   freqVector(m)*timeVector); %could be simplified but not critical
  %the important line
  if(logEnvelope)
  %convert envelope to dB
  % 255 = 0dBFS = |1| = |2^15| (full scale)
  %   0 = -90dBFS  = 0 = 0  (no sound)
    noiseBottom = 90; %dB
    pixelTop = 255; %brightest pixel value
    envelope = 10.^... %this undoes the Bel
               ( ((envelope*...
                  (noiseBottom/pixelTop) ...
                 )-noiseBottom)/10 ... %this /10 undoes the deci in deciBel
               );
  end
  if(verbose) %yes, hate me, tomas fault!
        figure;
        stem(envelope);
  end
  Rout = Rout + (sineVector.*envelope);
 end
end

%%Normalize
mRout = max(max(Rout));
if (mRout~=0) %avoid indian bread, thanks to andrekw
    %TODO convert volume to dB
    Rout = volume*Rout/max(max(Rout));
else
    disp('Image seems to contain no sound (max amplitude=0)');
end

%Save output to disk in audible format
wavwrite(Rout',44100,outputWav);


end