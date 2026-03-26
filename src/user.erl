-module(user).
-include("../include/chat.hrl").

-export([start/2, send_message/2, leave/1]).

start(ServerPid, Name) ->
    spawn(fun() -> init(ServerPid, Name) end).

send_message({ok, Pid}, Text) -> send_message(Pid, Text);

send_message(Pid, Text) when is_pid(Pid) ->
    case erlang:is_process_alive(Pid) of
        true -> Pid ! {send, Text};
        false -> {error, dead_process}
    end.

leave(UserPid) ->
   UserPid ! leave.

init(ServerPid, Name) ->
    ServerPid ! {join, Name, self()},
    receive
        {join_ok, ServerPid} ->
            io:format("[~p] Joined successfully.~n", [Name]),
            loop(ServerPid, Name);

        {join_rejected, duplicate_name} ->
            io:format("[~p] Name taken.~n", [Name])
    after 5000 ->
        io:format("[~p] Join timeout.~n", [Name])
    end.

loop(ServerPid, Name) ->
    receive
        {send, Text} ->
            io:format("[~p] <~p>: ~s~n", [Name, Name, Text]),
            ServerPid ! {message, self(), Text},
            loop(ServerPid, Name);

        leave ->
            ServerPid ! {leave, self()},
            receive
                leave_ok ->
                    io:format("[~p] Left chat.~n", [Name])
            after 3000 ->
                io:format("[~p] Leave timeout.~n", [Name])
            end,
            exit(normal);

        {chat_message, FromName, Text} ->
            io:format("[~p] <~p>: ~s~n", [Name, FromName, Text]),
            loop(ServerPid, Name);

        {server_notification, {user_joined, JoinedName}} ->
            io:format("[~p] ~p joined.~n", [Name, JoinedName]),
            loop(ServerPid, Name);

        {server_notification, {user_left, LeftName}} ->
            io:format("[~p] ~p left.~n", [Name, LeftName]),
            loop(ServerPid, Name);

        {server_notification, {user_disconnected, DisconnectedName}} ->
            io:format("[~p] ~p crashed.~n", [Name, DisconnectedName]),
            loop(ServerPid, Name);

        _Other ->
            loop(ServerPid, Name)
    end.