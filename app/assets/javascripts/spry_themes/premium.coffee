jQuery ->
  @stick_page_nav = ->
    $('#page-nav').stick_in_parent
      offset_top: 80
  @stick_page_nav()
  $(document).on 'page:done', @stick_page_nav
