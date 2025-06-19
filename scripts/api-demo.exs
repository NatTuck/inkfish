defmodule ApiDemo do

  def run() do
    hdrs = [
      {"x-auth", "A271A2AB73869927D323BF74E03DF6DC"}
    ]

    resp = HTTPoison.get!("http://localhost:4000/api/v1/subs", hdrs)
    IO.inspect(resp)
    IO.inspect(JSON.decode!(resp.body))
  end
end

ApiDemo.run()
