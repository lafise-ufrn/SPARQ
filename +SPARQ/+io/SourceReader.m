classdef SourceReader < handle
% SPARQ.io.SourceReader  Leitor reutilizavel de um arquivo MAT multissessao.

    properties (SetAccess = private)
        Source
        InputFormat
        BaseOptions
    end

    properties (Access = private)
        CacheKey = ""
        CacheData = []
        IsClosed = false
    end

    methods
        function obj = SourceReader(source, options)
            if nargin < 2 || isempty(options)
                options = struct();
            end
            if ~(ischar(source) || (isstring(source) && isscalar(source)))
                error('SPARQ:io:SourceReader:badSource', ...
                    'source must be a text scalar.');
            end
            if ~isstruct(options) || ~isscalar(options)
                error('SPARQ:io:SourceReader:badOptions', ...
                    'options must be a scalar struct.');
            end
            obj.Source = string(source);
            obj.BaseOptions = options;
            requested = "auto";
            if isfield(options, 'inputFormat')
                requested = string(options.inputFormat);
            end
            obj.InputFormat = SPARQ.internal.detectInputFormat(obj.Source, requested);
        end

        function inventory = inspect(obj)
            obj.assertOpen();
            inventory = SPARQ.internal.inspectSource( ...
                obj.Source, obj.InputFormat, obj.BaseOptions);
        end

        function session = load(obj, selector, overrides)
            obj.assertOpen();
            if nargin < 2 || isempty(selector)
                selector = struct();
            end
            if nargin < 3 || isempty(overrides)
                overrides = struct();
            end
            options = obj.BaseOptions;
            names = fieldnames(overrides);
            for i = 1:numel(names)
                options.(names{i}) = overrides.(names{i});
            end
            if obj.InputFormat == "longlfps"
                [session, obj.CacheKey, obj.CacheData] = ...
                    SPARQ.internal.loadLongLfps( ...
                    obj.Source, selector, options, obj.CacheKey, obj.CacheData);
            else
                session = SPARQ.internal.loadSource( ...
                    obj.Source, obj.InputFormat, selector, options);
            end
        end

        function close(obj)
            obj.CacheData = [];
            obj.CacheKey = "";
            obj.IsClosed = true;
        end
    end

    methods (Access = private)
        function assertOpen(obj)
            if obj.IsClosed
                error('SPARQ:io:SourceReader:closed', ...
                    'The source reader is already closed.');
            end
        end
    end
end
