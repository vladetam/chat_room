-module(chat_demo).
-export([run/0]).

run() ->
    % start server
    Server = server:start(),

    timer:sleep(500),

    % start users
    U1 = user:start(Server, "Alice"),
    U2 = user:start(Server, "Bob"),
    U3 = user:start(Server, "Charlie"),

    timer:sleep(1000),

    % send messages
    user:send_message(U1, "Hello everyone my name is Alice!"),
    timer:sleep(500),

    user:send_message(U2, "Hi Alice, i am Bob!"),
    timer:sleep(500),

    user:send_message(U3, "Hi i am Charlie!"),
    timer:sleep(500),

    % test duplicate name
    user:start(Server, "Alice"),

    timer:sleep(1000),

    % list users
    Server ! {list_users, self()},
    receive
        {user_list, Names} ->
            io:format("Active users: ~p~n", [Names])
    after 2000 ->
        io:format("Failed to get user list~n")
    end,

    timer:sleep(1000),

    % one user leaves
    user:leave(U2),

    timer:sleep(1000),

    % simulate crash (kill process)
    exit(U3, kill),

    timer:sleep(1000),

    % final message
    user:send_message(U1, "Hello just me now..."),

    ok.

%%chat_demo:run().