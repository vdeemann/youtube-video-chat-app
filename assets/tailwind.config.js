// See the Tailwind configuration guide for advanced usage
// https://tailwindcss.com/docs/configuration

const plugin = require("tailwindcss/plugin")

module.exports = {
  content: [
    "./js/**/*.js",
    "../lib/youtube_video_chat_app_web.ex",
    "../lib/youtube_video_chat_app_web/**/*.*ex"
  ],
  theme: {
    extend: {
      colors: {
        brand: "#9333EA",
      },
      animation: {
        'float-across': 'float-across linear forwards',
        'fade-in': 'fadeIn 0.3s ease-out forwards',
        'fade-out': 'fadeOut 0.3s ease-out forwards',
        'pulse': 'pulse 2s cubic-bezier(0.4, 0, 0.6, 1) infinite',
      },
      keyframes: {
        'float-across': {
          from: { transform: 'translateX(100vw)' },
          to: { transform: 'translateX(-100%)' }
        },
        fadeIn: {
          from: { 
            opacity: '0',
            transform: 'translateY(10px)'
          },
          to: { 
            opacity: '1',
            transform: 'translateY(0)'
          }
        },
        fadeOut: {
          to: { 
            opacity: '0',
            transform: 'translateY(-10px)'
          }
        }
      }
    },
  },
  plugins: [
    require("@tailwindcss/forms"),
    plugin(({addVariant}) => addVariant("phx-click-loading", [".phx-click-loading&", ".phx-click-loading &"])),
    plugin(({addVariant}) => addVariant("phx-submit-loading", [".phx-submit-loading&", ".phx-submit-loading &"])),
    plugin(({addVariant}) => addVariant("phx-change-loading", [".phx-change-loading&", ".phx-change-loading &"]))
  ]
}
