%% Write Predefined Animatlab Commands to the Microcontroller from Matlab.

%Clear Everything.
clear, close('all'), clc

%% Setup for Serial Port Communication.

%Define the baud rates.
baud_rate_animatlab = 115200; baud_rate_micro = 57600;

%Open the animatlab output and input serial ports.
serial_port_animatlab_output = OpenAtmegaSerialPort( 'COM9', baud_rate_animatlab ); serial_port_animatlab_input = OpenAtmegaSerialPort( 'COM11', baud_rate_animatlab );

%Open the serial ports.
serial_port_matlab_input = OpenAtmegaSerialPort( 'COM10', baud_rate_animatlab ); serial_port_matlab_output = OpenAtmegaSerialPort( 'COM13', baud_rate_animatlab );
serial_port_micro_input_output = OpenAtmegaSerialPort( 'COM6', baud_rate_micro );

%Set whether to print debug information.
bDebugPrint = false;

%Set whether to print sensor information.
bVerbose = false;

%Define the minimum number of bytes per sentence from animatlab.
min_num_bytes_per_sentence_animatlab = 12;

%Define the minimum number of bytes per sentence from the microcontroller.
min_num_bytes_per_sentence_micro = 8;

%Define the number of muscle pairs to simulate.
num_muscle_pairs = 3;

%Define the number of sensors.
num_sensors = 38;

%Define the sensor IDs.
sensor_IDs_crit = 1:38;

%% Read in Command Data From Previous Animatlab Simulations.

%Read in Animatlab muscle data.
animatlab_muscle_data = dlmread('C:\Users\USER\Documents\Coursework\MSME\Thesis\Animatlab\Simple_Quadruped\Simple_Quadruped\Front Left Leg Muscle Data.txt', '', 1, 0);

%Retrieve the animatlab time vector.
ts_animatlab = animatlab_muscle_data(:, 1);

%Retrieve the muscle tension values.
animatlab_muscle_tensions = animatlab_muscle_data(:, 3:2:end);

%Permute the columns of the animatlab muscle tensions so that the commands are ordered: hip, knee, ankle.
animatlab_muscle_tensions(:, :) = animatlab_muscle_tensions(:, [3 4 5 6 1 2]);

%Subsample the animatlab muscle tension data.
animatlab_muscle_tensions = animatlab_muscle_tensions(1:60:end, :);

%Define the number of commands to be sent.
num_commands = size(animatlab_muscle_tensions, 1);

%Define a time vector for data collection and simulation.
ts = 1:num_commands;

%% Pass Information Between Animatlab & the Micro Controller.

%Preallocate variables to store the reported front leg pressures and angles.
front_leg_pressures = zeros(6, num_commands); front_leg_angles = zeros(4, num_commands);

%Define the muscle IDs of interest.
muscle_ID_crits = 39:44;

%Preallocate a variable to store the received muscle commands from animatlab.
received_muscle_commands = zeros(length(muscle_ID_crits), num_commands);

%Initialize the old muscle and sensor value integers to be zero.
muscle_value_ints_old = zeros(1, length(muscle_ID_crits)); sensor_value_ints_old = zeros(1, num_sensors);

%Continuous pass information between animatlab & the micro controller.
for k = 1:num_commands
    
    %Start the timer.
    tic
    
    %Simulate animatlab data by writing to the animatlab output serial port.  Use this for testing the Matlab & Micro code with known input from Animatlab.
    serial_write_sensor_data2animatlab(serial_port_animatlab_output, animatlab_muscle_tensions(k, :), muscle_ID_crits )
    
    %Wait until animatlab sends a sentence to matlab.
    while (serial_port_matlab_input.BytesAvailable < min_num_bytes_per_sentence_animatlab), if bDebugPrint, fprintf('Waiting for Animatlab to Send Value: Bytes Available = %0.0f.\n', serial_port_matlab_input.BytesAvailable), end, end
    
    %Read in the animatlab sentence.
    [ muscle_values, muscle_IDs ] = ReadSentenceFromAnimatlab( serial_port_matlab_input );
    
    %Convert the muscle values to integers.
    muscle_value_ints = ConvertMuscleSingles2Integers( muscle_values );
    
    %Retrieve the animatlab command values associated with muscles with specific IDs.
    received_muscle_commands(:, k) = GetSpecificMuscleValues( muscle_IDs, muscle_value_ints_old, muscle_value_ints, muscle_ID_crits )';
    
    %Write the commands as ints to the microcontroller.
    serial_write_command_data_ints2micro(serial_port_micro_input_output, muscle_value_ints, muscle_IDs )
    
    %Wait until the microcontroller sends a sentence to matlab.
    while (serial_port_micro_input_output.BytesAvailable < min_num_bytes_per_sentence_micro), if bDebugPrint, fprintf('Waiting for Micro to Send Value. Bytes Available = %0.0f.\n', serial_port_micro_input_output.BytesAvailable), end, end
    
    %Read in the sensor data as ints from the microcontroller.
    [ sensor_value_ints, sensor_IDs ] = serial_read_micro_sensor_data_ints( serial_port_micro_input_output );
    
    %Determine where there was a check sum error and respond appropriately.
    if isempty(sensor_value_ints)                                                       %If there was a check sum error...
        sensor_value_ints = sensor_value_ints_old; sensor_IDs = sensor_IDs_crit;        %Replace the invalid sensor value integers and IDs with those from the previous reading.
    end
    
    %Conver the sensor data integers into doubles that are intelligible by Matlab.
    [sensor_value_doubles, sensor_voltages] = ConvertSensorInts2Doubles(sensor_value_ints);
    
    %Retrieve the sensor values associated with the front left leg.
    front_leg_pressures(:, k) = sensor_value_doubles(1:6)'; front_leg_angles(:, k) = sensor_value_doubles(25:28)';
    
    %Print out the front leg sensor values if desired.
    if bVerbose, fprintf('Front Leg Pressures: '), disp(front_leg_pressures(:, k)'), fprintf('Front Leg Angles: '), disp(front_leg_angles(:, k)'), end
    
    %Write the sensor data to animatlab.
    %     serial_write_sensor_data2animatlab(serial_port_matlab_output, values, IDs )
    
    %Update the old muscle value integers with the new muscle value integers.
    muscle_value_ints_old = muscle_value_ints; sensor_value_ints_old = sensor_value_ints;
    
    %Stop the timer.
    toc
    
end


%% Plot the Muscle Commands Recieved from Animatlab.

%Plot the muscle commands recieved from animatlab.
figure, hold on, grid on, xlabel('Command Number [#]'), ylabel('Muscle Command [0-65535]'), title('Animatlab Muscle Commands'), plot(1:num_commands, received_muscle_commands)
legend('Front Hip Extensor', 'Front Hip Flexor', 'Front Knee Extensor', 'Front Knee Flexor', 'Front Ankle Extensor', 'Front Ankle Flexor', 'Location', 'Best')


%% Plot the Sensor Data Recieved from the Microcontroller.

%Create a cell array to store the names of the muscle extensor/flexor pairs.
muscle_pair_names = {'Hip: ', 'Knee: ', 'Ankle: '};

%Define a column vector of RGB triplets to define the plot colors.
colors = [0 0 1; 0.5 0.5 1; 0 1 0; 0.75 1 0.75; 1 0 0; 1 0.5 0.5];

%Create a figure to store the muscle pressure vs iteration number plot.
figure

%Cycle through each muscle pair.
for k = 1:num_muscle_pairs                                                                          %Iterate through each muscle pair...
    
    %Create a subplot for this muscle extensor/flexor pair.
    subplot(1, 3, k), hold on, grid on, xlabel('Iteration Number [#]'), ylabel('Pressure [psi]'), title([muscle_pair_names{k} 'Muscle Pressure vs Iteration Number'])
    
    %Plot the extensor for this muscle pair.
    plot(ts, front_leg_pressures(k, :), '.-', 'Color', colors(2*k - 1, :), 'Markersize', 20)
    
    %Plot the flexor for this muscle pair.
    plot(ts, front_leg_pressures(k + 1, :), '.-', 'Color', colors(2*k, :), 'Markersize', 20)
    
    %Add a legend to the plot.
    legend('Extensor', 'Flexor', 'Location', 'Best')
    
end

%Create a cell array to store the names of the joints.
joint_names = {'Hip: ', 'Knee1: ', 'Knee2: ', 'Ankle: '};

%Create a figure for the joint angles.
figure

%Plot the value associated with each joint.
for k = 1:4                                         %Iterate through each of the joints...
    
    %Create a subplot for this joint.
    subplot(2, 2, k), hold on, grid on, xlabel('Iteration Number [#]'), ylabel('Angle [deg]'), title([joint_names{k} 'Joint Angle vs Iteration Number']), plot(ts, front_leg_angles(k, :), '.-', 'Markersize', 20)

end


%% Close All of the Serial Ports.
 
%Close the animatlab serial ports.
CloseSerialPort(serial_port_animatlab_output), CloseSerialPort(serial_port_animatlab_input)

%Close matlab's serial ports.
CloseSerialPort(serial_port_matlab_output), CloseSerialPort(serial_port_matlab_input)

%Close the microcontroller serial port.
CloseSerialPort(serial_port_micro_input_output)
