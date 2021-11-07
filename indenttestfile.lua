function some_fun(arg)
    local x = arg + 1

    local foo = function()
        local y = {
            1, 2, 3,
            4, 5,
            6
        }

        local z = {
            q = {
                p = {
                    1
                }
            }
        }

        local a = {
            p = 1 }

        some_fun(arg)

        some_fun(
            arg
        )

        some_fun(
            arg)

        some_fun(
            { arg })

    end

    return x
end
