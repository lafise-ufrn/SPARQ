function value = inputOption(options, name, defaultValue)
% value = SPARQ.internal.inputOption(options, name, defaultValue)

    if isfield(options, name)
        value = options.(name);
    else
        value = defaultValue;
    end
end
