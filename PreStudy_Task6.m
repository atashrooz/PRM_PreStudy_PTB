% Gabor Detection Threshold Task with Staircase Procedure - Psychtoolbox
% -----------------------------------------------------------------------
% This script conducts a study to approximate the detection threshold for
% Gabor stimuli using a 2-Up/1-Down staircase procedure targeting ~70% detection.

% 1. Housekeeping
clear; clc; close all;

%% ---------------------------
% 2. Task & Display Parameters
%% ---------------------------
numBlocks       = 1;   % Number of blocks
ISI             = 1;   % Inter-stimulus interval (seconds)
fixationDuration = 0.5; % Fixation cross duration (seconds)
maxResponseTime = 3;   % Max time (seconds) to wait for a yes/no response
backgroundColor = [128 128 128]; % Gray background
fixationColor   = [0 0 0];       % Black fixation cross
fixationSize    = 25;  % Pixel length of fixation cross arms

% Staircase parameters
initialContrast = 0.2;   % Starting contrast level
contrastStep    = 0.02;  % Contrast adjustment step size
minContrast     = 0.01;  % Minimum allowable contrast
maxContrast     = 0.5;   % Maximum allowable contrast
maxReversals    = 8;     % Maximum number of reversals before stopping

% Participant information
participant.id     = "02"; 
participant.gender = "M";
participant.age    = 25;

%% -----------------------------
% 3. Setup Psychtoolbox & Screen
%% -----------------------------
Screen('Preference', 'SkipSyncTests', 1); % (Disable in production)
[window, windowRect] = PsychImaging('OpenWindow', max(Screen('Screens')), backgroundColor);
[xCenter, yCenter]   = RectCenter(windowRect); % Screen center
ifi                  = Screen('GetFlipInterval', window);

KbName('UnifyKeyNames');
exitKey     = KbName('ESCAPE');
yesKey      = KbName('y');  % Press 'Y' if they see the Gabor
noKey       = KbName('n');  % Press 'N' if they do not
priorityLevel = MaxPriority(window);
Priority(priorityLevel);

HideCursor;

%% --------------------------------------
% 4. Generate a Base Gabor (random orientation)
%% --------------------------------------
gaborSize   = 300;       % Size in pixels
spatialFreq = 7 / gaborSize; % 7 cycles in the Gabor stimulus
[x, y]      = meshgrid(-gaborSize/2 : gaborSize/2, -gaborSize/2 : gaborSize/2);
lambda      = 1/spatialFreq; % Wavelength in pixels
phase       = 0;             % Phase offset
sigma       = gaborSize/6;   % Std dev of Gaussian envelope

% Noise level for 'imnoise' function:
noiseLevel = 0.3;

%% ----------------------------------------------------
% 5. Data Structure to Store Results (Initialize empty)
%% ----------------------------------------------------
results = struct('id', [], 'gender', [], 'age', [], ...
    'block', [], 'trial', [], 'contrastUsed', [], ...
    'stimPresent', [], 'response', [], 'correct', [], ...
    'reactionTime', []);

% Staircase variables
currentContrast = initialContrast;
reversalCount   = 0;
lastDirection   = 0; % 1 = increase, -1 = decrease, 0 = start
consecutiveIncorrect = 0; % Count consecutive incorrect responses

%% 6. Instructions to the Participant
instructionText = sprintf(['Welcome to the Gabor Detection Task.\n\n' ...
    'On each trial:\n' ...
    ' - A fixation cross will appear.\n' ...
    ' - A stimulus with noise may or may not be presented.\n\n' ...
    'Please press **Y** if you see the Gabor,\n' ...
    'or **N** if you do not.\n\n' ...
    'Press any key to start...']);

DrawFormattedText(window, instructionText, 'center', 'center', [0 0 0]);
Screen('Flip', window);
KbStrokeWait;

%% 7. MAIN EXPERIMENT LOOP
try
    trialCount = 0;  % A counter to index trials in 'results'
    
    while reversalCount < maxReversals
        trialCount = trialCount + 1;
        
        %% 7.1 Fixation Cross
        Screen('DrawLine', window, fixationColor, ...
            xCenter - fixationSize, yCenter, xCenter + fixationSize, yCenter, 2);
        Screen('DrawLine', window, fixationColor, ...
            xCenter, yCenter - fixationSize, xCenter, yCenter + fixationSize, 2);

        %% 7.2 Decide whether to present Gabor or not (50/50)
        stimPresent = (rand < 0.5); % 1 = Gabor present, 0 = no Gabor
        
        %% 7.3 Create the stimulus
        if stimPresent
            % Generate a random orientation between 90 and 180 degrees
            theta = (90 + (180 - 90) * rand) * (pi / 180); % Convert to radians
            % Multiply base Gabor by the chosen contrast (range ~ [-contrast, +contrast])
            gaborMatrix = exp(-((x.^2 + y.^2) / (2 * sigma^2))) .* ...
                          cos(2 * pi * (x * cos(theta) + y * sin(theta)) / lambda + phase);
            gaborMatrix = gaborMatrix * currentContrast;
            gaborMatrix = gaborMatrix + 0.5;
            noisyGabor = imnoise(gaborMatrix, 'gaussian', 0, noiseLevel);
            stimulus = uint8(noisyGabor * 255);
        else
            noisePatch = imnoise(ones(size(x)) * 0.5, 'gaussian', 0, noiseLevel);
            stimulus   = uint8(noisePatch * 255);
        end

        % Make texture
        stimTexture = Screen('MakeTexture', window, stimulus);
        
        %% 7.4 Present the Stimulus
        Screen('DrawTexture', window, stimTexture, [], [], []);
        Screen('DrawLine', window, fixationColor, ...
            xCenter - fixationSize, yCenter, xCenter + fixationSize, yCenter, 2);
        Screen('DrawLine', window, fixationColor, ...
            xCenter, yCenter - fixationSize, xCenter, yCenter + fixationSize, 2);
        startTrialTime = Screen('Flip', window);
        tic;  % Start measuring reaction time
        
        %% 7.5 Collect Yes/No Response
        response = NaN;
        correctFlag = NaN;
        rt = NaN;

        while toc < maxResponseTime
            [keyIsDown, ~, keyCode] = KbCheck;
            if keyIsDown
                if keyCode(exitKey)
                    error('Experiment terminated by user via ESC.');
                elseif keyCode(yesKey)
                    response = 1; % "Yes, I see it"
                    rt = toc * 1000; % Reaction time in ms
                    break;
                elseif keyCode(noKey)
                    response = 0; % "No, I do not see it"
                    rt = toc * 1000; % Reaction time in ms
                    break;
                end
            end
        end

        % Timeout response
        if isnan(response)
            response = -1; % No response
            rt = NaN;
        end

        % Determine correctness
        if stimPresent && response == 1
            correctFlag = 1;
        elseif ~stimPresent && response == 0
            correctFlag = 1;
        else
            correctFlag = 0;
        end

        %% 7.6 Update Staircase
        if correctFlag
            consecutiveIncorrect = 0;
            if lastDirection == 1
                reversalCount = reversalCount + 1;
            end
            lastDirection = -1;
            currentContrast = max(minContrast, currentContrast - contrastStep);
        else
            consecutiveIncorrect = consecutiveIncorrect + 1;
            if consecutiveIncorrect >= 2
                if lastDirection == -1
                    reversalCount = reversalCount + 1;
                end
                lastDirection = 1;
                currentContrast = min(maxContrast, currentContrast + contrastStep);
                consecutiveIncorrect = 0;
            end
        end

        Screen('Close', stimTexture);
        
        %% 7.7 ISI
        Screen('FillRect', window, backgroundColor);
        Screen('Flip', window);
        WaitSecs(ISI);

        %% 7.8 Store trial data
        results(trialCount).id            = participant.id;
        results(trialCount).gender        = participant.gender;
        results(trialCount).age           = participant.age;
        results(trialCount).block         = 1;
        results(trialCount).trial         = trialCount;
        results(trialCount).contrastUsed  = currentContrast;
        results(trialCount).stimPresent   = stimPresent;
        results(trialCount).response      = response;
        results(trialCount).correct       = correctFlag;
        results(trialCount).reactionTime  = rt;
    end

    %% 8. End of experiment: Save data
    resultsTable = struct2table(results);
    saveFileName = sprintf('Participant_%s_Data_Staircase.xlsx', participant.id);
    writetable(resultsTable, saveFileName);
    fprintf('Data saved to %s\n', saveFileName);

catch ME
    sca;
    Priority(0);
    rethrow(ME);
end

%% 9. Cleanup
sca;
Priority(0);
ShowCursor;
