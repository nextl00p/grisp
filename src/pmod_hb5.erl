-module(pmod_hb5).

-behavior(gen_server).

% API
-export([start_link/2]).
-export([stop/1, forward/1, backward/1, get_direction/1]).

% Callbacks
-export([init/1]).
-export([handle_call/3]).
-export([handle_cast/2]).
-export([handle_info/2]).
-export([code_change/3]).
-export([terminate/2]).

-include("grisp.hrl").

%--- API -----------------------------------------------------------------------

% @private
start_link(Slot, _Opts) ->
    gen_server:start_link(?MODULE, Slot, []).

forward(Slot) -> call(Slot, {direction, forward}).

backward(Slot) -> call(Slot, {direction, backward}).

stop(Slot) -> call(Slot, {direction, stop}).

get_direction(Slot) -> call(Slot, get_direction).

%--- Callbacks -----------------------------------------------------------------

% @private
init([Slot]) when (Slot =:= gpio1) or (Slot =:= gpio2) ->
    grisp_gpio:configure_slot(Slot, {output_0, output_0, input, input}),
    grisp_devices:register(Slot, ?MODULE),
    {ok, {Slot, undefined}};
init([Slot]) ->
    error({incompatible_slot, Slot}).
    
% @private
handle_call({direction, Direction}, _From, {_Slot, Direction} = State) ->
    {reply, ok, State};
handle_call({direction, Direction}, _From, {Slot, Direction}) ->
    motor(Slot, Direction),
    {reply, ok, {Slot, Direction}};
handle_call(get_direction, _From, {_Slot, Direction} = State) ->
    {reply, Direction, State};
handle_call(Request, From, _State) -> error({unknown_request, Request, From}).

% @private
handle_cast(Request, _State) -> error({unknown_cast, Request}).

% @private
handle_info(Info, _State) -> error({unknown_info, Info}).

% @private
code_change(_OldVsn, State, _Extra) -> {ok, State}.

% @private
terminate(_Reason, _State) -> ok.

%--- Internal -------------------------------------------------------------------

call(Slot, Call) ->
    Dev = grisp_devices:slot(Slot),
    case gen_server:call(Dev#device.pid, Call) of
        {error, Reason} -> error(Reason);
        Result          -> Result
    end.

motor(Slot, start) -> grisp_gpio:set(Slot, 2);
motor(Slot, stop) -> grisp_gpio:clear(Slot, 2);
motor(Slot, forward) ->
    motor(Slot, stop),    % Never change direction on a active H-bridge
    grisp_gpio:clear(Slot, 1),
    motor(Slot, start);
motor(Slot, backward) ->
    motor(Slot, stop),	  % Never change direction on a active H-bridge
    grisp_gpio:set(Slot, 1),
    motor(Slot, start).
