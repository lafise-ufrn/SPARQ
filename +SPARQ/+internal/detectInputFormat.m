function format = detectInputFormat(source, requested)
% format = SPARQ.internal.detectInputFormat(source, requested)
%
% Aceita exclusivamente arquivos MAT. O formato interno distingue apenas o
% layout generico e os dois presets MAT conhecidos pela biblioteca.

    source = string(source);
    if exist(source, 'file') ~= 2
        error('SPARQ:io:detectInputFormat:notFound', ...
            'Source MAT file does not exist: %s', source);
    end
    [~, ~, extension] = fileparts(source);
    if ~strcmpi(extension, '.mat')
        error('SPARQ:io:detectInputFormat:unsupportedExtension', ...
            'SPARQ accepts electrophysiology recordings only from .mat files: %s', source);
    end

    requested = lower(string(requested));
    if strlength(requested) > 0 && requested ~= "auto"
        format = normalizeFormat(requested);
        return;
    end

    variables = string({whos('-file', source).name});
    if ismember("RUN", variables)
        format = "realdata";
    elseif all(ismember(["LFPallAtrials", "LFPallVtrials", ...
            "NewAreas", "srate"], variables))
        format = "longlfps";
    else
        format = "mat";
    end
end

function format = normalizeFormat(format)
    supported = ["mat", "realdata", "longlfps"];
    if ~ismember(format, supported)
        error('SPARQ:io:detectInputFormat:unknownFormat', ...
            'Unsupported MAT InputFormat "%s".', format);
    end
end
