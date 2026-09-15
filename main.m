%% SPARQ - INTERFACE GRAFICA INTERATIVA
% Execute este arquivo para abrir o fluxo principal do SPARQ.
%
% Na interface:
%   1. escolha a pasta com as gravacoes MAT;
%   2. selecione uma sessao;
%   3. clique no inicio e no fim de um trecho de referencia limpa;
%   4. ajuste os parametros e acompanhe o sinal marcado e o resumo percentual;
%   5. salve a sessao atual ou todas as sessoes de uma vez.

libraryRoot = fileparts(mfilename('fullpath'));
addpath(libraryRoot);
SPARQ_GUI_APP = SPARQ_GUI();
