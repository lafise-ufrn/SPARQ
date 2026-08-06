function limits = plotTimeLimits(session, params)
% limits = SPARQ.internal.plotTimeLimits(session, params)
%
% Resolve o intervalo temporal dos plots multicanal. Sessoes legadas usam
% os eventos configurados; sessoes canonicas sem esses eventos usam toda a
% extensao de session.time.

    limits = double([session.time(1), session.time(end)]);
    required = [params.channels.referenceEventStart, ...
        params.channels.referenceEventEnd];
    if isfield(session, 'events') && numel(session.events) >= max(required)
        candidate = double(session.events(required));
        if all(isfinite(candidate)) && candidate(2) > candidate(1)
            limits = candidate;
        end
    end
end
