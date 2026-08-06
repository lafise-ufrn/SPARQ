function info = version()
% info = SPARQ.version()
%
% Retorna a identidade versionada da biblioteca e do esquema de resultados.
%
% SAIDAS:
%   info = struct com .name, .version, .status e .resultSchemaVersion

    info.name = "SPARQ";
    info.version = "0.3.0-beta.1";
    info.status = "beta";
    info.resultSchemaVersion = "1.0";
end
