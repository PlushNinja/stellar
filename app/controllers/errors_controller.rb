class ErrorsController < ApplicationController

  def show
    @status_code = (request.path.match(/\d{3}/) || ['500'])[0].to_i
  end
end
