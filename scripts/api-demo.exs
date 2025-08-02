defmodule ApiDemo do

  def run() do
    hdrs = [
      {"x-auth", "A271A2AB73869927D323BF74E03DF6DC"}
    ]

    resp = Req.get!("http://localhost:4000/api/v1/subs?assignment_id=22", headers: hdrs)
    IO.inspect(resp)
    IO.inspect(resp.body)
  end
end

ApiDemo.run()
