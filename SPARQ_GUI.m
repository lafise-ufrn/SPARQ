function app = SPARQ_GUI(varargin)
% SPARQ_GUI  Abre a interface grafica interativa do SPARQ.
%
% USO:
%   SPARQ_GUI
%   app = SPARQ_GUI
%
% A interface permite carregar sessoes MAT, selecionar a referencia limpa,
% ajustar os parametros, observar o sinal marcado e o resumo percentual
% atualizarem sem reiniciar o programa e salvar uma ou todas as sessoes em
% pastas de resultado individuais.

    libraryRoot = fileparts(mfilename('fullpath'));
    addpath(libraryRoot);
    app = SPARQ.App(varargin{:});
end
