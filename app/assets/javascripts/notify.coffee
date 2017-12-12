UnobtrusiveFlash.mapping =
  notice:
    class: 'info'
    icon: 'fa fa-info-circle'
  alert:
    class: 'warning'
    icon: 'fa fa-warning'
  error:
    class: 'danger'
    icon: 'fa fa-times-rectangle'

UnobtrusiveFlash.showFlashMessage = (message, type) ->
  $.notify(
    {
      icon: UnobtrusiveFlash.mapping[type].icon
      message: message
    },
    {
      type: UnobtrusiveFlash.mapping[type].class
      newest_on_top: true
      placement:
        from: 'bottom'
        align: 'center'
      offset: 60
      z_index: 1051
      mouse_over: 'pause'
      animate:
        enter: 'animated fadeInUp'
        exit: 'animated flipOutX'
    }
  )

@notify = (e, params) ->
  UnobtrusiveFlash.showFlashMessage params.message, params.type

$(window).on 'rails:flash', @notify
