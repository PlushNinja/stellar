(function(){var e,r;$(function(){return r(),e()}),r=function(){if($(document).on("progressive_render:end",e),$(document).on("ajax:end",e),window.Turbolinks)return $(document).on("turbolinks:load",e)},e=function(){return $("[data-progressive-render-placeholder=true]").each(function(){var e;return e=$(this),e.attr("data-progressive-render-placeholder",!1),$.ajax({url:e.data("progressive-render-path"),cache:!1,success:function(r){return e.html(r),$(document).trigger("progressive_render:end")}})})}}).call(this);