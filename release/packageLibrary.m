function archivePath = packageLibrary(outputDirectory)
% archivePath = packageLibrary(outputDirectory)
%
% Cria um arquivo ZIP versionado com codigo, testes, demos e documentacao.

    if nargin < 1 || isempty(outputDirectory)
        outputDirectory = fullfile(tempdir, 'SPARQ-release');
    end
    releaseDir = fileparts(mfilename('fullpath'));
    libraryRoot = fileparts(releaseDir);
    required = {'LICENSE', 'CITATION.cff'};
    for i = 1:numel(required)
        if exist(fullfile(libraryRoot, required{i}), 'file') ~= 2
            error('SPARQ:package:missingReleaseMetadata', ...
                'Cannot package a public release without %s.', required{i});
        end
    end
    if exist(outputDirectory, 'dir') ~= 7
        mkdir(outputDirectory);
    end

    versionInfo = SPARQ.version();
    archivePath = fullfile(outputDirectory, ...
        sprintf('SPARQ-%s.zip', versionInfo.version));
    include = {'+SPARQ', 'demo', 'tests', 'benchmarks', 'Contents.m', ...
        'main.m', 'defaultNoiseParameters.m', 'cleanExperiment.m', 'runNoiseCleaning.m', ...
        'README.md', 'README.pt-BR.md', 'CHANGELOG.md', 'CONTRIBUTING.md', ...
        'SECURITY.md', 'LICENSE', 'CITATION.cff'};
    paths = cellfun(@(x) fullfile(libraryRoot, x), include, ...
        'UniformOutput', false);
    zip(archivePath, paths, libraryRoot);
end
