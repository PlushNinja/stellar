$.fn.extend
  fillViewport: ->
    $(this).height $(window).height() - $('.layout-container').offset().top

@viewportUpdate = ->
  $('.viewport').each ->
    $(this).fillViewport()

$(window).resize -> viewportUpdate()
