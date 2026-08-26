document.addEventListener("DOMContentLoaded", function () {
  document.querySelectorAll(".gallery-wrapper .justified-gallery").forEach(function (gallery, index) {
    var group = gallery.id || ("gallery-" + index);

    gallery.querySelectorAll("a[href]").forEach(function (link) {
      link.setAttribute("data-rel", group);
    });
  });
});
