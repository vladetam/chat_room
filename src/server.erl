-module(server).
-include("../include/chat.hrl").

-export([start/0, init/0, loop/1]).

start() ->
    spawn(?MODULE, init, []).

init() ->
    process_flag(trap_exit, true),
    io:format("[Server] Chat server started. PID: ~p~n", [self()]),
    loop([]).

loop(Users) ->
    receive
        {join, Name, UserPid} ->
            case find_by_name(Name, Users) of
                {ok, _} ->
                    UserPid ! {join_rejected, duplicate_name},
                    io:format("[Server] Join rejected for ~p (duplicate).~n", [Name]),
                    loop(Users);

                not_found ->
                    link(UserPid),
                    NewUser = #user{name = Name, pid = UserPid},
                    UserPid ! {join_ok, self()},
                    broadcast_notification({user_joined, Name}, Users),
                    io:format("[Server] ~p joined. Total: ~p~n", [Name, length(Users)+1]),
                    loop([NewUser | Users])
            end;

        {message, FromPid, Text} ->
            case find_by_pid(FromPid, Users) of
                {ok, #user{name = FromName}} ->
                    Others = [U || U <- Users, U#user.pid =/= FromPid],
                    broadcast_message(FromName, Text, Others);
                not_found ->
                    ok
            end,
            loop(Users);

        {leave, FromPid} ->
            case find_by_pid(FromPid, Users) of
                {ok, #user{name = Name}} ->
                    FromPid ! leave_ok,
                    UpdatedUsers = remove_by_pid(FromPid, Users),
                    broadcast_notification({user_left, Name}, UpdatedUsers),
                    io:format("[Server] ~p left. Total: ~p~n", [Name, length(UpdatedUsers)]),
                    loop(UpdatedUsers);
                not_found ->
                    loop(Users)
            end;

        {'EXIT', FromPid, Reason} ->
            case find_by_pid(FromPid, Users) of
                {ok, #user{name=Name}} ->
                    UpdatedUsers = remove_by_pid(FromPid, Users),
                    case Reason of
                        normal ->
                            broadcast_notification({user_left, Name}, UpdatedUsers),
                            io:format("[Server] ~p left. Total: ~p~n", [Name, length(UpdatedUsers)]);
                        _ ->
                            broadcast_notification({user_disconnected, Name}, UpdatedUsers),
                            io:format("[Server] ~p crashed (~p). Total: ~p~n", [Name, Reason, length(UpdatedUsers)])
                    end,
                    loop(UpdatedUsers);
                not_found -> loop(Users)
            end;

        {list_users, CallerPid} ->
            UserNames = [U#user.name || U <- Users],
            CallerPid ! {user_list, UserNames},
            loop(Users);

        _Other ->
            loop(Users)
    end.

broadcast_message(FromName, Text, Users) ->
    lists:foreach(fun(#user{pid = Pid}) ->
        catch Pid ! {chat_message, FromName, Text}
    end, Users).

broadcast_notification(Notification, Users) ->
    lists:foreach(fun(#user{pid = Pid}) ->
        catch Pid ! {server_notification, Notification}
    end, Users).

find_by_name(Name, Users) ->
    case lists:keyfind(Name, #user.name, Users) of
        false -> not_found;
        User -> {ok, User}
    end.

find_by_pid(Pid, Users) ->
    case lists:keyfind(Pid, #user.pid, Users) of
        false -> not_found;
        User -> {ok, User}
    end.

remove_by_pid(Pid, Users) ->
    lists:keydelete(Pid, #user.pid, Users).