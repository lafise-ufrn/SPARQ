function writeReferenceCacheFixture( ...
        cacheFile, sourceFile, nSamples, timeBounds, referenceSeconds)
% writeReferenceCacheFixture  Cria um cache que representa dois cliques manuais.

    cacheDirectory = fileparts(cacheFile);
    if exist(cacheDirectory, 'dir') ~= 7
        mkdir(cacheDirectory);
    end

    cacheMetadata.schemaVersion = "1.0";
    cacheMetadata.nSamples = nSamples;
    cacheMetadata.timeBounds = double(timeBounds(:).');
    if strlength(string(sourceFile)) > 0
        cacheMetadata.sourceIdentity = ...
            SPARQ.internal.sourceIdentity(sourceFile);
    else
        cacheMetadata.sourceIdentity.path = "";
        cacheMetadata.sourceIdentity.exists = false;
        cacheMetadata.sourceIdentity.bytes = NaN;
        cacheMetadata.sourceIdentity.modifiedDatenum = NaN;
        cacheMetadata.sourceIdentity.token = "in-memory";
    end
    referenceSeconds = double(referenceSeconds(:).');
    save(cacheFile, 'referenceSeconds', 'cacheMetadata');
end
