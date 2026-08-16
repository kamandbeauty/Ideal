using System;
using RubyRun3D.Services;
using UnityEngine;
using UnityEngine.EventSystems;
using UnityEngine.InputSystem.UI;
using UnityEngine.UI;

namespace RubyRun3D.UI
{
    public sealed class UIManager:MonoBehaviour
    {
        Canvas canvas;Font font;GameObject screen;Text stageText,coinsText,armyText,feedbackText;
        readonly Color plum=new(.23f,.12f,.34f,.94f),violet=new(.46f,.24f,.72f),gold=new(1f,.68f,.12f),cream=new(1f,.94f,.82f);
        public void Initialize()
        {
            font=Resources.GetBuiltinResource<Font>("LegacyRuntime.ttf");
            var canvasGo=new GameObject("RubyRun_UI");canvasGo.transform.SetParent(transform);canvas=canvasGo.AddComponent<Canvas>();canvas.renderMode=RenderMode.ScreenSpaceOverlay;
            canvasGo.AddComponent<CanvasScaler>().uiScaleMode=CanvasScaler.ScaleMode.ScaleWithScreenSize;canvasGo.GetComponent<CanvasScaler>().referenceResolution=new Vector2(720,1280);
            canvasGo.AddComponent<GraphicRaycaster>();
            var eventSystem=new GameObject("EventSystem");eventSystem.transform.SetParent(transform);eventSystem.AddComponent<EventSystem>();eventSystem.AddComponent<InputSystemUIInputModule>();
        }
        public void ShowMenu(int coins,int stage,Action play,Action upgrades,Action skins,Action settings,Action daily)
        {
            Clear();screen=Panel("MenuShade",canvas.transform,new Color(.07f,.04f,.12f,.48f),Vector2.zero,Vector2.one);
            Label(screen.transform,"RUBY RUN 3D",58,new Vector2(40,1020),new Vector2(640,120),cream);
            Label(screen.transform,"روبی ران  •  STAGE "+stage,27,new Vector2(40,955),new Vector2(640,60),gold);
            Label(screen.transform,$"◆ {coins}",30,new Vector2(480,1180),new Vector2(200,60),gold);
            Button(screen.transform,"PLAY  •  بازی",new Vector2(120,720),new Vector2(480,90),play,gold,plum);
            Button(screen.transform,"UPGRADES",new Vector2(120,610),new Vector2(480,78),upgrades,violet,cream);
            Button(screen.transform,"SKINS",new Vector2(120,515),new Vector2(480,78),skins,violet,cream);
            Button(screen.transform,"DAILY REWARD",new Vector2(120,420),new Vector2(480,78),daily,violet,cream);
            Button(screen.transform,"SETTINGS",new Vector2(120,325),new Vector2(480,78),settings,violet,cream);
        }
        public void ShowHud(int stage,int coins,int army)
        {
            Clear();screen=new GameObject("HUD");screen.transform.SetParent(canvas.transform,false);var rect=screen.AddComponent<RectTransform>();Stretch(rect);
            var top=Panel("TopBar",screen.transform,plum,new Vector2(.03f,.9f),new Vector2(.97f,.985f));
            stageText=Label(top.transform,$"STAGE {stage}",25,new Vector2(15,5),new Vector2(200,70),cream);
            coinsText=Label(top.transform,$"◆ {coins}",25,new Vector2(250,5),new Vector2(180,70),gold);
            armyText=Label(top.transform,$"ARMY {army}",25,new Vector2(450,5),new Vector2(200,70),cream);
            feedbackText=Label(screen.transform,"DRAG TO CHOOSE",30,new Vector2(80,190),new Vector2(560,70),cream);feedbackText.canvasRenderer.SetAlpha(.75f);
        }
        public void UpdateArmy(int count){if(armyText)armyText.text=$"ARMY {count}";}
        public void GateFeedback(string operation,int before,int after)
        {
            if(!feedbackText)return;feedbackText.text=$"{before}  {operation}  →  {after}";feedbackText.color=after>=before?new Color(.3f,1f,.55f):new Color(1f,.3f,.3f);feedbackText.canvasRenderer.SetAlpha(1);
            feedbackText.CrossFadeAlpha(0,1.4f,false);
        }
        public void ShowResult(bool victory,int coins,int remaining,Action next,Action retry,Action home)
        {
            Clear();screen=Panel("Result",canvas.transform,new Color(.06f,.03f,.1f,.84f),Vector2.zero,Vector2.one);
            Label(screen.transform,victory?"★ STAGE COMPLETE":"GAME OVER",50,new Vector2(40,870),new Vector2(640,130),victory?gold:new Color(1f,.3f,.3f));
            Label(screen.transform,$"COINS  +{(victory?coins:0)}\nSOLDIERS  {remaining}",30,new Vector2(100,680),new Vector2(520,150),cream);
            if(victory)Button(screen.transform,"NEXT",new Vector2(120,520),new Vector2(480,90),next,gold,plum);
            Button(screen.transform,"RETRY",new Vector2(120,410),new Vector2(480,80),retry,violet,cream);
            Button(screen.transform,"HOME",new Vector2(120,310),new Vector2(480,80),home,violet,cream);
        }
        public void ShowList(string title,string[] rows,Action[] actions,Action back)
        {
            Clear();screen=Panel("List",canvas.transform,plum,Vector2.zero,Vector2.one);Label(screen.transform,title,48,new Vector2(40,1080),new Vector2(640,100),cream);
            var y=940f;for(var i=0;i<rows.Length;i++){var index=i;Button(screen.transform,rows[i],new Vector2(85,y),new Vector2(550,78),()=>actions[index](),violet,cream);y-=92;}
            Button(screen.transform,"‹ BACK",new Vector2(85,90),new Vector2(550,75),back,new Color(.16f,.12f,.24f),cream);
        }
        public void ShowConfirm(string message,Action confirm,Action cancel)
        {
            Clear();screen=Panel("Confirm",canvas.transform,plum,Vector2.zero,Vector2.one);Label(screen.transform,message,34,new Vector2(70,690),new Vector2(580,250),cream);
            Button(screen.transform,"CONFIRM",new Vector2(110,500),new Vector2(500,85),confirm,new Color(.8f,.2f,.25f),cream);Button(screen.transform,"CANCEL",new Vector2(110,395),new Vector2(500,85),cancel,violet,cream);
        }
        public void Toast(string text){if(!feedbackText)return;feedbackText.text=text;feedbackText.canvasRenderer.SetAlpha(1);feedbackText.CrossFadeAlpha(0,1.8f,false);}
        void Clear(){if(screen)Destroy(screen);}
        GameObject Panel(string name,Transform parent,Color color,Vector2 min,Vector2 max){var go=new GameObject(name);go.transform.SetParent(parent,false);var rect=go.AddComponent<RectTransform>();rect.anchorMin=min;rect.anchorMax=max;rect.offsetMin=rect.offsetMax=Vector2.zero;go.AddComponent<Image>().color=color;return go;}
        Text Label(Transform parent,string value,int size,Vector2 position,Vector2 dimensions,Color color){var go=new GameObject("Text");go.transform.SetParent(parent,false);var rect=go.AddComponent<RectTransform>();rect.anchorMin=rect.anchorMax=Vector2.zero;rect.anchoredPosition=position;rect.sizeDelta=dimensions;rect.pivot=Vector2.zero;var text=go.AddComponent<Text>();text.font=font;text.text=value;text.fontSize=size;text.fontStyle=FontStyle.Bold;text.alignment=TextAnchor.MiddleCenter;text.color=color;text.resizeTextForBestFit=true;text.resizeTextMinSize=16;text.resizeTextMaxSize=size;return text;}
        void Button(Transform parent,string title,Vector2 position,Vector2 size,Action action,Color background,Color foreground){var go=Panel("Button_"+title,parent,background,Vector2.zero,Vector2.zero);var rect=go.GetComponent<RectTransform>();rect.anchoredPosition=position;rect.sizeDelta=size;rect.pivot=Vector2.zero;var button=go.AddComponent<Button>();button.targetGraphic=go.GetComponent<Image>();button.onClick.AddListener(()=>action());Label(go.transform,title,28,Vector2.zero,size,foreground);}
        static void Stretch(RectTransform rect){rect.anchorMin=Vector2.zero;rect.anchorMax=Vector2.one;rect.offsetMin=rect.offsetMax=Vector2.zero;}
    }
}
