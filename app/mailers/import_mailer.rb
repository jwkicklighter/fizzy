class ImportMailer < ApplicationMailer
  def completed(import)
    @import = import
    @identity = import.identity

    mail to: @identity.email_address, subject: "Your Fizzy account import is complete"
  end
end
