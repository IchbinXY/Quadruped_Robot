function [muscle_values, ts, num_commands] = GenerateSquareCommands(num_muscles, num_cycles, num_per_cycle, on_value)
%% Function Description.

% This function generates a matrix of muscle commands, muscle_values, of
% dimension num_commands x num_muscles, that cause the muscle to alternate
% between extension & contraction phases using square waves with the given properties.


%% Define Default Input Arguments.

% Define the default input arguments.
if nargin < 4, on_value = 450; end                      % [-] Muscle On Value.
if nargin < 3, num_per_cycle = 100; end                 % [#] Number of Points per Cycle.
if nargin < 2, num_cycles = 5; end                      % [#] Number of Cycles to Generate.
if nargin < 1, num_muscles = 24; end                    % [#] Number of Muscles.

%% Generate the On/Off Commands.

% Compute the total number of commands to be sent.
num_commands = num_per_cycle*(num_cycles + 1);

% Create a template row for the animatlab muscle tension matrix.
template_row = zeros(1, num_muscles);
template_row(2:2:end) = ones(1, length(template_row(2:2:end)));

% Initialize the animatlab muscle tension matrix.
muscle_values = zeros(num_commands, num_muscles);

% Initialize a counter variable.
k3 = 0;

% Create the Animatlab muscle tension matrix row by row.
for k1 = 1:(2*num_cycles)                           % Iterate through each of the cycles...
    for k2 = 1:num_per_cycle               % Iterate through each of the other commands per cycle...
        
        % Advance the counter.
        k3 = k3 + 1;
        
        if (mod(k1, 2) == 0)
            muscle_values(k3, :) = on_value*template_row;
        else
            muscle_values(k3, :) = on_value*(~template_row);
        end
        
    end
end

% Set the final command set to zero.
for k = 1:num_per_cycle
    muscle_values(k3 + k, :) = zeros(1, num_muscles);
end

%Define a time vector for data collection and simulation.
ts = 1:num_commands;


end
