function identity = sourceIdentity(filePath)
% identity = SPARQ.internal.sourceIdentity(filePath)

    identity.path = string(filePath);
    identity.exists = exist(filePath, 'file') == 2 || exist(filePath, 'dir') == 7;
    identity.isDirectory = exist(filePath, 'dir') == 7;
    identity.bytes = NaN;
    identity.modifiedDatenum = NaN;
    identity.token = "missing";
    if ~identity.exists
        return;
    end
    listing = dir(filePath);
    if identity.isDirectory
        listing = listing(~[listing.isdir]);
        identity.bytes = sum([listing.bytes]);
        if isempty(listing)
            identity.modifiedDatenum = NaN;
        else
            identity.modifiedDatenum = max([listing.datenum]);
        end
    else
        identity.bytes = listing.bytes;
        identity.modifiedDatenum = listing.datenum;
    end
    identity.token = string(sprintf('metadata-v1:%d:%.15g', ...
        identity.bytes, identity.modifiedDatenum));
end
