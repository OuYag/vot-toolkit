function [tracker] = create_tracker(identifier, varargin)

version = [];

for i = 1:2:length(varargin)
    switch lower(varargin{i})
        case 'version'
            version = varargin{i+1};            
        otherwise 
            error(['Unknown switch ', varargin{i},'!']) ;
    end
end 

if isempty(version)
    tokens = regexp(identifier,':','split');
    if numel(tokens) > 2
        error('Error: %s is not a valid tracker identifier.', identifier);
    elseif numel(tokens) == 2
        family_identifier = tokens{1}; % Override family identifier
        version = tokens{2}; % The second part is the version
    else
        family_identifier = identifier; % By default these are both the same
    end;
else
    family_identifier = identifier;
    identifier = sprintf('%s:%s', identifier, num2str(version));
end;

if ~valid_identifier(family_identifier)
    error('Error: %s is not a valid tracker identifier.', family_identifier);
end;

result_directory = fullfile(get_global_variable('directory'), 'results', identifier);

mkpath(result_directory);

if exist(['tracker_' , identifier]) ~= 2 %#ok<EXIST>
    
    if ~isempty(version)
        tracker_label = sprintf('%s (%s)', family_identifier, num2str(version));
    end;
    
    print_debug('WARNING: No configuration for tracker %s found', identifier);
    tracker = struct('identifier', identifier, 'command', [], ...
        'directory', result_directory, 'linkpath', [], ...
        'label', tracker_label, 'autogenerated', true, 'metadata', struct(), ...
		'interpreter', [], 'trax', false, 'version', version, ...
        'family', family_identifier);
else

	tracker_metadata = struct();
	tracker_label = identifier;
	tracker_interpreter = [];
	tracker_linkpath = {};
	tracker_trax = true;

	tracker_configuration = str2func(['tracker_' , family_identifier]);
	tracker_configuration();

	tracker_label = strtrim(tracker_label);

    if ~isempty(version)
        tracker_label = sprintf('%s (%s)', tracker_label, num2str(version));
    end;

	tracker = struct('identifier', identifier, 'command', tracker_command, ...
		    'directory', result_directory, 'linkpath', {tracker_linkpath}, ...
		    'label', tracker_label, 'interpreter', tracker_interpreter, ...
		    'autogenerated', false, 'version', version, 'family', family_identifier);
		
	if tracker_trax
		trax_executable = get_global_variable('trax_client', '');
		if isempty(trax_executable) && ~isempty(tracker.command)
		    error('TraX support not available');
		end;
		tracker.run = @trax_wrapper;
		tracker.trax = true;
		tracker.linkpath{end+1} = fullfile(matlabroot, 'bin', lower(computer('arch')));
	else
		tracker.run = @system_wrapper; %#ok<UNRCH>
		tracker.trax = false;
	end;

	if isstruct(tracker_metadata)
		tracker.metadata = tracker_metadata;
	else
		tracker.metadata = struct();
	end;
end;

performance_filename = fullfile(tracker.directory, 'performance.txt');

if exist(performance_filename, 'file')
    tracker.performance = readstruct(benchmark_hardware(tracker));
end;


