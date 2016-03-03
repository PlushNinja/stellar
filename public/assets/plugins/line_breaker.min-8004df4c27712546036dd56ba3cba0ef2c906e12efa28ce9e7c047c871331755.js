/*!
 * froala_editor v2.2.0 (https://www.froala.com/wysiwyg-editor)
 * License https://froala.com/wysiwyg-editor/terms
 * Copyright 2014-2016 Froala Labs
 */
!function(e){"function"==typeof define&&define.amd?define(["jquery"],e):"object"==typeof module&&module.exports?module.exports=function(t,n){return void 0===n&&(n="undefined"!=typeof window?require("jquery"):require("jquery")(t)),e(n),n}:e(jQuery)}(function(e){"use strict";e.extend(e.FE.DEFAULTS,{lineBreakerTags:["table","hr","iframe","form","dl"],lineBreakerOffset:15}),e.FE.PLUGINS.lineBreaker=function(t){function n(n,r){var o,a,i,s,f,l,u,p;if(null==n)s=r.parent(),f=s.offset().top,u=r.offset().top,o=u-Math.min((u-f)/2,t.opts.lineBreakerOffset),i=s.outerWidth(),a=s.offset().left;else if(null==r)s=n.parent(),l=s.offset().top+s.outerHeight(),p=n.offset().top+n.outerHeight(),o=p+Math.min((l-p)/2,t.opts.lineBreakerOffset),i=s.outerWidth(),a=s.offset().left;else{s=n.parent();var g=n.offset().top+n.height(),v=r.offset().top;if(g>v)return!1;o=(g+v)/2,i=s.outerWidth(),a=s.offset().left}t.opts.iframe&&(a+=t.$iframe.offset().left-e(t.o_win).scrollLeft(),o+=t.$iframe.offset().top-e(t.o_win).scrollTop()),t.$box.append(d),d.css("top",o-t.win.pageYOffset),d.css("left",a-t.win.pageXOffset),d.css("width",i),d.data("tag1",n),d.data("tag2",r),d.addClass("fr-visible").data("instance",t)}function r(e,r){var a,i,s=e.offset().top,f=e.offset().top+e.outerHeight();if(Math.abs(f-r)<=t.opts.lineBreakerOffset||Math.abs(r-s)<=t.opts.lineBreakerOffset)if(Math.abs(f-r)<Math.abs(r-s)){i=e.get(0);for(var l=i.nextSibling;l&&l.nodeType==Node.TEXT_NODE&&0===l.textContent.length;)l=l.nextSibling;if(!l)return n(e,null),!0;if(a=o(l))return n(e,a),!0}else{if(i=e.get(0),!i.previousSibling)return n(null,e),!0;if(a=o(i.previousSibling))return n(a,e),!0}d.removeClass("fr-visible").removeData("instance")}function o(n){if(n){var r=e(n);if(0===t.$el.find(r).length)return null;if(n.nodeType!=Node.TEXT_NODE&&t.opts.lineBreakerTags.indexOf(n.tagName.toLowerCase())>=0)return r;if(r.parents(t.opts.lineBreakerTags.join(",")).length>0)return n=r.parents(t.opts.lineBreakerTags.join(",")).get(0),e(n)}return null}function a(n){c=null;var a,i,s,f=null,l=t.doc.elementFromPoint(n.pageX-t.win.pageXOffset,n.pageY-t.win.pageYOffset);if(l&&("HTML"==l.tagName||"BODY"==l.tagName||t.node.isElement(l)))for(a=1;a<=t.opts.lineBreakerOffset;a++){if(i=t.doc.elementFromPoint(n.pageX-t.win.pageXOffset,n.pageY-t.win.pageYOffset-a),i&&!t.node.isElement(i)&&i!=t.$wp.get(0)&&e(i).parents(t.$wp).length){f=o(i);break}if(s=t.doc.elementFromPoint(n.pageX-t.win.pageXOffset,n.pageY-t.win.pageYOffset+a),s&&!t.node.isElement(s)&&s!=t.$wp.get(0)&&e(s).parents(t.$wp).length){f=o(s);break}}else f=o(l);f?r(f,n.pageY):t.core.sameInstance(d)&&d.removeClass("fr-visible").removeData("instance")}function i(e){return d.hasClass("fr-visible")&&!t.core.sameInstance(d)?!1:t.popups.areVisible()||t.$el.get(0).querySelectorAll(".fr-selected-cell").length?(d.removeClass("fr-visible"),!0):void(v===!1&&(c&&clearTimeout(c),c=setTimeout(a,30,e)))}function s(){c&&clearTimeout(c),d.hasClass("fr-visible")&&d.removeClass("fr-visible").removeData("instance")}function f(){v=!0,s()}function l(){v=!1}function u(n){if(!t.core.sameInstance(d))return!0;n.preventDefault(),d.removeClass("fr-visible").removeData("instance");var r=d.data("tag1"),o=d.data("tag2"),a=t.html.defaultTag();null==r?a&&"TD"!=o.parent().get(0).tagName?o.before("<"+a+">"+e.FE.MARKERS+"<br></"+a+">"):o.before(e.FE.MARKERS+"<br>"):a&&"TD"!=r.parent().get(0).tagName?r.after("<"+a+">"+e.FE.MARKERS+"<br></"+a+">"):r.after(e.FE.MARKERS+"<br>"),t.selection.restore()}function p(){t.shared.$line_breaker||(t.shared.$line_breaker=e('<div class="fr-line-breaker"><a class="fr-floating-btn" role="button" tabindex="-1" title="'+t.language.translate("Break")+'"><svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32"><rect x="21" y="11" width="2" height="8"/><rect x="14" y="17" width="7" height="2"/><path d="M14.000,14.000 L14.000,22.013 L9.000,18.031 L14.000,14.000 Z"/></svg></a></div>')),d=t.shared.$line_breaker,t.events.on("shared.destroy",function(){d.html("").removeData().remove()},!0),t.events.on("destroy",function(){d.removeData("instance").removeClass("fr-visible").appendTo("body")},!0),t.events.$on(d,"mouseleave",s,!0),t.events.$on(d,"mousemove",function(e){e.stopPropagation()},!0),t.events.$on(d,"mousedown","a",function(e){e.stopPropagation()},!0),t.events.$on(d,"click","a",u,!0)}function g(){return t.$wp?(p(),v=!1,t.events.$on(t.$win,"mousemove",i),t.events.$on(e(t.win),"scroll",s),t.events.on("popups.show.table.edit",s),t.events.$on(e(t.win),"mousedown",f),void t.events.$on(e(t.win),"mouseup",l)):!1}var d,v,c;return{_init:g}}});