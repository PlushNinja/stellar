(function(){$("#none-confirm-form").on("submit",function(t){var n;return t.preventDefault(),n=$.post($(this).attr("action")),n.done(function(){return $("#checkout-form").trigger("submit.rails")})})}).call(this);