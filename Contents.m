% SPARQ  Detection and masking of multichannel LFP noise.
%
% Generic data and batch APIs:
%   main                         - Run the guided generic folder workflow.
%   SPARQ.createSession       - Build a canonical in-memory session.
%   SPARQ.processingOptions   - Create experiment-neutral processing options.
%   SPARQ.createManifest      - Build an explicit batch manifest.
%   SPARQ.discoverSessions    - Discover logical sessions in MAT files.
%   SPARQ.validateManifest    - Validate and normalize a manifest.
%   SPARQ.runBatch            - Run a generic reproducible batch.
%   SPARQ.io.open             - Open a reusable MAT-file reader.
%   SPARQ.io.load             - Load one selected MAT session.
%   SPARQ.io.loadMat          - Load configurable variables from MAT files.
%   SPARQ.io.saveResult       - Save a versioned result with provenance.
%   SPARQ.reference.selectInteractive - Select/cache a visual reference.
%
% Legacy treadmill/odor compatibility:
%   defaultNoiseParameters      - Return the frozen legacy profile.
%   cleanExperiment             - Process the legacy folder hierarchy.
%   runNoiseCleaning            - Legacy batch with frozen defaults.
%   SPARQ.loadSession           - Load one legacy treadmill/odor MAT session.
%   SPARQ.runSession            - Process one legacy treadmill/odor MAT session.
%   SPARQ.profiles.esteiraOdor - Explicit legacy compatibility profile.
%
% Scientific core:
%   SPARQ.processSession     - Detect noise and construct clean outputs.
%   SPARQ.version            - Return software and result-schema versions.
