function net = loadTrainedModel()
% LOADTRAINEDMODEL  Loads the trained DR classification network from disk,
% caching it so it's only read from disk once per MATLAB session.
%
% Looks for: models/dr_model.mat  (created by trainDRModel.m)
%
% OUTPUT:
%   net - the trained network, or [] if no trained model exists yet
%         (this lets the rest of the pipeline run with placeholders
%         before you've trained anything)

    persistent cached_net

    if isempty(cached_net)
        model_path = fullfile('models', 'dr_model.mat');
        if isfile(model_path)
            loaded = load(model_path, 'net');
            cached_net = loaded.net;
            fprintf('Loaded trained model from %s\n', model_path);
        else
            cached_net = [];
            warning('loadTrainedModel:notFound', ...
                'No trained model found at %s yet. Run trainDRModel.m first, or continue testing with placeholder results.', ...
                model_path);
        end
    end

    net = cached_net;
end
