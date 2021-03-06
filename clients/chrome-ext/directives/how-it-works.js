angular.module("UIComponent").directive("howItWorks",["i18nService",function(i18nService){

    return {
        restrict: 'E',
        replace: true,
        scope: {
            popupTarget:"@"
        },
        controller:["$scope","ModalService",function($scope, ModalService){

            $scope.howItWorks = function(){

                var explanation = i18nService._($scope.popupTarget+"-popup-text");

                ModalService.showModal({

                    templateUrl: '/operando/tpl/modals/how_does_it_work.html',
                    controller: ["$scope", "close", "watchDogService", function ($scope, close, watchDogService) {
                        $scope.explanation = explanation;
                    }]

                }).then(function (modal) {
                    modal.element.modal({
                        backdrop: 'static'
                    });
                });
            }
        }],
        template: '<a class="how_it_works" ng-click="howItWorks();">How does it work?</a>'
    }
}]);
