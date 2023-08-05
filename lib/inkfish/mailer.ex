defmodule Inkfish.Mailer do
  use Swoosh.Mailer, otp_app: :inkfish

  def config do
    Application.get_env(:inkfish, Inkfish.Mailer)
  end

  def send_from() do
    conf = config()
    conf[:send_from] || {"Inkfish", "no-reply@example.com"}
  end
end
